#!/usr/bin/env bash
# Restructures build/web after `flutter build web --base-href /app/` so that:
#   build/web/app/   <- Flutter app (served at hablotengo.com/app)
#   build/web/       <- Static home page

restructure_web() {
  echo "=== Restructuring build output ==="

  mv build/web build/web_tmp
  mkdir build/web
  mv build/web_tmp build/web/app

  for d in common; do
    [ -d "build/web/app/$d" ] && mv "build/web/app/$d" "build/web/"
  done

  mv build/web/app/home.html build/web/index.html
  cp build/web/app/favicon.png build/web/
  cp build/web/app/hablo.png build/web/

  echo "  Done. Flutter app -> build/web/app/, home page -> build/web/"
}
