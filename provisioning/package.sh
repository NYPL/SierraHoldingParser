rm -rf build

# Build dependencies:
gem update --system
gem install bundler

bundle config set deployment 'true'
bundle install --without=test

# Move required application files into build:
mkdir build
cp *.rb build/.
cp -R lib build/.
cp -R vendor build/.

cd build/
zip -qr build.zip *
