"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  IMMUTABLE_RELEASE_ASSETS,
  RELEASE_IDENTITY,
  RELEASE_ASSET_GUARD_STATE,
  evaluateReleaseAssetGuard,
} = require("./release_asset_guard");

test("loads the Superghost immutable asset names from release identity", () => {
  assert.equal(RELEASE_IDENTITY.dmgAssetName, "superghost-macos.dmg");
  assert.equal(RELEASE_IDENTITY.appcastAssetName, "superghost-appcast.xml");
  assert.deepEqual(
    IMMUTABLE_RELEASE_ASSETS.slice(0, 2),
    [RELEASE_IDENTITY.dmgAssetName, RELEASE_IDENTITY.appcastAssetName],
  );
});

test("marks guard as complete and skips build/upload when all immutable assets already exist", () => {
  const result = evaluateReleaseAssetGuard({
    existingAssetNames: [...IMMUTABLE_RELEASE_ASSETS, "notes.txt"],
  });

  assert.deepEqual(result.conflicts, IMMUTABLE_RELEASE_ASSETS);
  assert.deepEqual(result.missingImmutableAssets, []);
  assert.equal(result.guardState, RELEASE_ASSET_GUARD_STATE.COMPLETE);
  assert.equal(result.hasPartialConflict, false);
  assert.equal(result.shouldSkipBuildAndUpload, true);
  assert.equal(result.shouldSkipUpload, true);
});

test("marks guard as clear when immutable assets are not present", () => {
  const result = evaluateReleaseAssetGuard({
    existingAssetNames: ["notes.txt", "checksums.txt"],
  });

  assert.deepEqual(result.conflicts, []);
  assert.deepEqual(result.missingImmutableAssets, IMMUTABLE_RELEASE_ASSETS);
  assert.equal(result.guardState, RELEASE_ASSET_GUARD_STATE.CLEAR);
  assert.equal(result.hasPartialConflict, false);
  assert.equal(result.shouldSkipBuildAndUpload, false);
  assert.equal(result.shouldSkipUpload, false);
});

test("marks guard as partial when only some immutable assets exist", () => {
  const partialAssets = [RELEASE_IDENTITY.appcastAssetName, "cmuxd-remote-manifest.json"];
  const result = evaluateReleaseAssetGuard({
    existingAssetNames: partialAssets,
  });

  assert.deepEqual(result.conflicts, partialAssets);
  assert.deepEqual(
    result.missingImmutableAssets,
    IMMUTABLE_RELEASE_ASSETS.filter((assetName) => !partialAssets.includes(assetName)),
  );
  assert.equal(result.guardState, RELEASE_ASSET_GUARD_STATE.PARTIAL);
  assert.equal(result.hasPartialConflict, true);
  assert.equal(result.shouldSkipBuildAndUpload, false);
  assert.equal(result.shouldSkipUpload, false);
});
