#!/bin/sh
# Copies the Gift Keeper web app into www/ for the iPhone and Android apps, then syncs it into both projects.
# Run after every change to app.html:  cd native && ./build-web.sh
set -e
cd "$(dirname "$0")"
rm -rf www && mkdir -p www
cp ../app.html www/index.html
cp ../privacy.html ../terms.html ../manifest.webmanifest www/
cp -R ../img ../brand www/
npx cap sync
