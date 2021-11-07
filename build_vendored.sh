# Build all project-local, vendored dependencies

echo "Building GLFW..."
pushd ./vendor/glfw
cmake -S ./ -B ./build
cd ./build
make
popd
pwd
return

echo "Building epoxy..."
pushd ./vendor/libepoxy
mkdir -p _build
cd _build
meson
ninja
popd
