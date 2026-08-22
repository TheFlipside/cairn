<?php

declare(strict_types=1);

/**
 * SPDX-FileCopyrightText: 2026 Max Fiedler
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

namespace OCA\Cairn\Service;

use OCA\Cairn\Reading\Clock;
use OCA\Cairn\Reading\HealthQueryService;
use OCA\Cairn\Reading\SystemClock;

/**
 * Builds a read path bound to one user.
 *
 * The pure layer takes its storage, its clock and its timezone as arguments and
 * knows nothing about Nextcloud. This is the single place those three are
 * supplied, so there is one answer to "which timezone are we in" rather than one
 * per caller — which is exactly the kind of drift that would make two screens of
 * the same app disagree about which day a reading belongs to.
 */
final class QueryFactory {
	/**
	 * `$clock` is injectable for the same reason it is on the query service:
	 * almost every query is defined relative to today, so a test that reads the
	 * wall clock passes on the day it is written and fails the following week.
	 * Nextcloud's container supplies only the first two; the default is built
	 * per call, because it needs the timezone resolved at that moment.
	 */
	public function __construct(
		private readonly NextcloudShardSource $shards,
		private readonly DisplayTimeZone $timeZone,
		private readonly ?Clock $clock = null,
	) {
	}

	public function forUser(string $userId): HealthQueryService {
		$display = $this->timeZone->get();

		return new HealthQueryService(
			shards: new UserShardSource($this->shards, $userId),
			clock: $this->clock ?? new SystemClock($display),
			display: $display,
		);
	}
}
