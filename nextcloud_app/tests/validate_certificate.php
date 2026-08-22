<?php

declare(strict_types=1);

/**
 * SPDX-FileCopyrightText: 2026 Max Fiedler
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Checks the committed code-signing certificate.
 *
 * WHY THIS EXISTS. `cairn.crt` is the public half of the keypair the Nextcloud
 * app store verifies releases against. It is committed on purpose — it carries
 * nothing secret, and having it here lets anyone check a release signature
 * against the same certificate the store used.
 *
 * Two failures it catches, both of which are quiet until they are expensive:
 *
 *   1. The wrong certificate. Its subject must name this app: a certificate for
 *      a different app id produces signatures the store rejects at upload, long
 *      after the release was cut.
 *   2. Expiry. This one is a time bomb — the certificate is good for a decade,
 *      so nothing will go wrong until one day releases stop being accepted and
 *      nobody remembers why. The check warns while there is still time to
 *      request a new one.
 *
 * The private key is NOT here and never will be; `.githooks/pre-commit` refuses
 * `*.key`, `*.pem` and `*.p8`. See docs/RELEASE.md §6.
 *
 * Run from this app's directory:  php tests/validate_certificate.php
 *
 * Exit status: 0 clean, 1 findings, 2 the check could not run.
 */

/** Warn this far ahead, so a replacement can be requested unhurried. */
const RENEW_WARNING_DAYS = 90;

/** Who Nextcloud's app-store certificates are signed by. */
const EXPECTED_ISSUER = 'Nextcloud';

if (!extension_loaded('openssl')) {
	fwrite(STDERR, "PHP has no openssl extension, so the certificate cannot be read.\n");
	fwrite(STDERR, "Run this inside the dev container: nextcloud_app/dev check\n");
	exit(2);
}

$appRoot = dirname(__DIR__);
$certPath = $appRoot . '/cairn.crt';
$infoPath = $appRoot . '/appinfo/info.xml';

if (!is_file($certPath)) {
	fwrite(STDERR, "No certificate at {$certPath}.\n");
	fwrite(STDERR, "Releases cannot be signed without one — see docs/RELEASE.md §6.\n");
	exit(1);
}

$pem = file_get_contents($certPath);
if ($pem === false) {
	fwrite(STDERR, "Could not read {$certPath}.\n");
	exit(2);
}

// A private key here would be a serious mistake, and one worth naming loudly
// rather than letting a parse failure hint at.
if (str_contains($pem, 'PRIVATE KEY')) {
	fwrite(STDERR, "{$certPath} contains a PRIVATE KEY.\n");
	fwrite(STDERR, "Remove it, and treat the key as compromised: this file is public.\n");
	exit(1);
}

$certificate = openssl_x509_parse($pem);
if ($certificate === false) {
	fwrite(STDERR, "{$certPath} is not a readable X.509 certificate.\n");
	exit(1);
}

/** @var list<string> $findings */
$findings = [];

$appId = '';
if (is_file($infoPath)) {
	// SimpleXML answers for any element name, so `?? ''` never fires — an
	// absent <id> yields an empty element, which casts to the empty string.
	// Reading it that way says what actually happens.
	$info = simplexml_load_file($infoPath);
	$appId = $info === false ? '' : trim((string)$info->id);
}
$subject = (string)($certificate['subject']['CN'] ?? '');
if ($appId !== '' && $subject !== $appId) {
	$findings[] = "subject is '{$subject}', but appinfo/info.xml declares the app id "
		. "'{$appId}' — signatures from this certificate would be rejected.";
}

$issuer = (string)($certificate['issuer']['O'] ?? $certificate['issuer']['CN'] ?? '');
if (!str_contains($issuer, EXPECTED_ISSUER)) {
	$findings[] = "issuer is '{$issuer}', not " . EXPECTED_ISSUER
		. ' — the app store only accepts certificates it counter-signed.';
}

$expiresAt = $certificate['validTo_time_t'] ?? null;
if (!is_int($expiresAt)) {
	$findings[] = 'the certificate has no readable expiry date.';
	$expiresAt = 0;
}

$daysLeft = (int)floor(($expiresAt - time()) / 86400);
if ($daysLeft < 0) {
	$findings[] = 'the certificate expired ' . abs($daysLeft)
		. ' days ago; request a replacement before releasing again.';
}

if ($findings !== []) {
	fwrite(STDERR, "Certificate check failed:\n");
	foreach ($findings as $finding) {
		fwrite(STDERR, "  {$finding}\n");
	}
	exit(1);
}

$expiry = date('Y-m-d', $expiresAt);
if ($daysLeft < RENEW_WARNING_DAYS) {
	fwrite(STDERR, "warning: the signing certificate expires on {$expiry}, in {$daysLeft} days.\n");
	fwrite(STDERR, "Request a replacement now — see docs/RELEASE.md §6.\n");
}

echo "certificate: '{$subject}', issued by {$issuer}, valid until {$expiry}.\n";
exit(0);
