dartdoc --no-code --exclude-lib=metadata --mode=static lib/js.dart
cp -r example web
pub deploy
rm -rf web
