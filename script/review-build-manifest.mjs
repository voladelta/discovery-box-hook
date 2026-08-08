#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const repositoryRoot = process.cwd();
const launchPath = "submissions/discovery-box/launch.json";

let mode;
let manifestPath;
try {
  ({ mode, manifestPath } = parseArguments(process.argv.slice(2)));
  const manifest = buildManifest();
  const encoded = `${canonicalJson(manifest)}\n`;

  if (mode === "write") {
    fs.writeFileSync(resolveRepositoryPath(manifestPath), encoded);
    process.stdout.write(`Wrote ${manifestPath}\n`);
  } else {
    const expected = fs.readFileSync(resolveRepositoryPath(manifestPath), "utf8");
    if (expected !== encoded) {
      throw new Error(`${manifestPath} does not match the exact compiler output`);
    }
    process.stdout.write(`Verified ${manifestPath}\n`);
  }
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}

function parseArguments(args) {
  if (args.length !== 2 || !new Set(["--write", "--check"]).has(args[0])) {
    throw new Error("Usage: review-build-manifest.mjs (--write|--check) <manifest-path>");
  }
  return {
    mode: args[0] === "--write" ? "write" : "check",
    manifestPath: validateRepositoryPath(args[1])
  };
}

function buildManifest() {
  const launch = readJson(launchPath);
  const buildInfoPaths = fs.readdirSync(resolveRepositoryPath("out/build-info"))
    .filter((entry) => entry.endsWith(".json"))
    .map((entry) => `out/build-info/${entry}`)
    .sort(compareUtf8);
  if (buildInfoPaths.length !== 1) {
    throw new Error(`Expected exactly one Foundry build-info file, found ${buildInfoPaths.length}`);
  }

  const buildInfoPath = buildInfoPaths[0];
  const buildInfoBytes = fs.readFileSync(resolveRepositoryPath(buildInfoPath));
  const buildInfo = JSON.parse(buildInfoBytes.toString("utf8"));
  if (buildInfo.solcVersion !== launch.compiler.version) {
    throw new Error("Build-info compiler version does not match launch.json");
  }

  const sources = Object.entries(buildInfo.input?.sources ?? {})
    .map(([sourcePath, source]) => sourceRecord(sourcePath, source))
    .sort((left, right) => compareUtf8(left.path, right.path));
  if (sources.length === 0) throw new Error("Build-info contains no compiler sources");

  const deployableRecords = [
    ...launch.targets.map((target) => ({
      id: target.targetId,
      role: "release-target",
      sourceUnitName: target.sourceUnitName,
      contractName: target.contractName
    })),
    ...(launch.extensions?.internalChildPlans ?? []).map((child) => ({
      id: child.childId,
      role: "internal-child",
      sourceUnitName: child.sourceUnitName,
      contractName: child.contractName
    }))
  ]
    .sort((left, right) => compareUtf8(left.id, right.id))
    .map(artifactRecord);

  const settings = buildInfo.input?.settings;
  if (!isPlainObject(settings)) throw new Error("Build-info compiler settings are missing");
  const normalizedCompilerInput = normalizeCompilerInput(buildInfo.input);
  const normalizedBuildInfo = {
    _format: buildInfo._format,
    source_id_to_path: buildInfo.source_id_to_path,
    language: buildInfo.language,
    input: normalizedCompilerInput,
    output: buildInfo.output,
    solcLongVersion: buildInfo.solcLongVersion,
    solcVersion: buildInfo.solcVersion
  };
  const normalizedBuildInfoBytes = Buffer.from(canonicalJson(normalizedBuildInfo), "utf8");
  const launchSettings = launch.compiler?.settings;
  if (!isPlainObject(launchSettings)) throw new Error("launch.json compiler settings are missing");

  const sourceClosureSha256 = digestCanonical(sources);
  const artifactSetSha256 = digestCanonical(deployableRecords);
  return {
    schemaVersion: "discovery-box.reproducible-build.v2",
    subject: {
      applicationId: launch.applicationId,
      chain: launch.chain,
      launchSpecificationPath: launchPath,
      launchSpecificationSha256: digest(fs.readFileSync(resolveRepositoryPath(launchPath)))
    },
    compiler: {
      family: launch.compiler.family,
      profileId: launch.compiler.profileId,
      version: buildInfo.solcVersion,
      longVersion: buildInfo.solcLongVersion,
      launchSettings,
      resolvedSettings: settings,
      resolvedSettingsSha256: digestCanonical(settings),
      compilerInputSha256: digestCanonical(normalizedCompilerInput)
    },
    sourceClosure: {
      method: "solc-input-literal-content-v1",
      fileCount: sources.length,
      sha256: sourceClosureSha256,
      files: sources
    },
    buildInfo: {
      format: buildInfo._format,
      normalization: "repository-root-paths-v1",
      normalizedByteLength: normalizedBuildInfoBytes.length,
      normalizedSha256: digest(normalizedBuildInfoBytes),
      compilerOutputSha256: digestCanonical(buildInfo.output),
      sourceIdMapSha256: digestCanonical(buildInfo.source_id_to_path)
    },
    deployableArtifacts: {
      count: deployableRecords.length,
      sha256: artifactSetSha256,
      artifacts: deployableRecords
    }
  };
}

function normalizeCompilerInput(input) {
  if (!isPlainObject(input)) throw new Error("Build-info compiler input is missing");
  const normalized = JSON.parse(JSON.stringify(input));
  normalized.basePath = normalizeCompilerPath(normalized.basePath, "basePath");
  for (const field of ["allowPaths", "includePaths"]) {
    if (!Array.isArray(normalized[field]) || normalized[field].some((entry) => typeof entry !== "string")) {
      throw new Error(`Build-info compiler input ${field} is malformed`);
    }
    normalized[field] = normalized[field].map((entry) => normalizeCompilerPath(entry, field));
  }
  return normalized;
}

function normalizeCompilerPath(value, field) {
  if (typeof value !== "string" || !path.isAbsolute(value)) {
    throw new Error(`Build-info compiler input ${field} must use an absolute host path`);
  }
  const relative = path.relative(repositoryRoot, value);
  if (path.isAbsolute(relative) || relative === ".." || relative.startsWith(`..${path.sep}`)) {
    throw new Error(`Build-info compiler input ${field} escapes the repository`);
  }
  return relative === "" ? "." : relative.split(path.sep).join("/");
}

function sourceRecord(sourcePath, source) {
  validateRepositoryPath(sourcePath);
  if (!isPlainObject(source) || typeof source.content !== "string") {
    throw new Error(`Build-info source ${sourcePath} has no literal content`);
  }
  const diskBytes = fs.readFileSync(resolveRepositoryPath(sourcePath));
  const compilerBytes = Buffer.from(source.content, "utf8");
  if (!diskBytes.equals(compilerBytes)) {
    throw new Error(`Build-info source ${sourcePath} differs from the repository bytes`);
  }
  return {
    path: sourcePath,
    byteLength: diskBytes.length,
    sha256: digest(diskBytes)
  };
}

function artifactRecord(subject) {
  validateRepositoryPath(subject.sourceUnitName);
  if (!/^[A-Za-z_$][A-Za-z0-9_$]*$/u.test(subject.contractName)) {
    throw new Error(`Invalid contract name for ${subject.id}`);
  }
  const artifactPath = `out/${path.posix.basename(subject.sourceUnitName)}/${subject.contractName}.json`;
  const artifactBytes = fs.readFileSync(resolveRepositoryPath(artifactPath));
  const artifact = JSON.parse(artifactBytes.toString("utf8"));
  const creationBytecode = decodeBytecode(artifact.bytecode?.object, `${subject.id} creation bytecode`);
  const runtimeBytecode = decodeBytecode(artifact.deployedBytecode?.object, `${subject.id} runtime bytecode`);

  return {
    id: subject.id,
    role: subject.role,
    sourceUnitName: subject.sourceUnitName,
    contractName: subject.contractName,
    artifactPath,
    artifactByteLength: artifactBytes.length,
    artifactSha256: digest(artifactBytes),
    abiSha256: digestCanonical(artifact.abi),
    creationBytecode: {
      byteLength: creationBytecode.length,
      sha256: digest(creationBytecode),
      linkReferences: artifact.bytecode.linkReferences
    },
    runtimeBytecode: {
      byteLength: runtimeBytecode.length,
      sha256: digest(runtimeBytecode),
      immutableReferences: artifact.deployedBytecode.immutableReferences,
      linkReferences: artifact.deployedBytecode.linkReferences
    }
  };
}

function decodeBytecode(value, label) {
  if (typeof value !== "string" || !/^0x(?:[0-9a-fA-F]{2})+$/u.test(value)) {
    throw new Error(`${label} is missing or malformed`);
  }
  return Buffer.from(value.slice(2), "hex");
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(resolveRepositoryPath(filePath), "utf8"));
}

function resolveRepositoryPath(filePath) {
  const validated = validateRepositoryPath(filePath);
  const resolved = path.resolve(repositoryRoot, validated);
  const prefix = `${path.resolve(repositoryRoot)}${path.sep}`;
  if (!resolved.startsWith(prefix)) throw new Error(`Path escapes repository: ${filePath}`);
  return resolved;
}

function validateRepositoryPath(value) {
  if (
    typeof value !== "string"
    || value.length === 0
    || path.isAbsolute(value)
    || value.includes("\\")
    || value.split("/").some((segment) => segment === "" || segment === "." || segment === "..")
  ) {
    throw new Error(`Invalid repository path: ${value}`);
  }
  return value;
}

function digest(value) {
  return `sha256:${crypto.createHash("sha256").update(value).digest("hex")}`;
}

function digestCanonical(value) {
  return digest(Buffer.from(canonicalJson(value), "utf8"));
}

function canonicalJson(value) {
  return JSON.stringify(sortJson(value));
}

function sortJson(value) {
  if (Array.isArray(value)) return value.map(sortJson);
  if (!isPlainObject(value)) return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort(compareUtf8)
      .map((key) => [key, sortJson(value[key])])
  );
}

function compareUtf8(left, right) {
  return Buffer.compare(Buffer.from(left, "utf8"), Buffer.from(right, "utf8"));
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
