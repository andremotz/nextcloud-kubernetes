#!/bin/sh
# Runs once, after the image's automatic installation (post-installation hook).
# The cron sidecar runs cron.php every five minutes; tell Nextcloud to rely on
# it instead of the default AJAX mode, which only runs while a browser is open.
set -eu
php /var/www/html/occ background:cron
