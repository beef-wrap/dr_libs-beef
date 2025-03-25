cmake -S . -B dr_libs/build -DCMAKE_BUILD_TYPE=Debug
cmake --build dr_libs/build --config Debug

cmake -S . -B dr_libs/build -DCMAKE_BUILD_TYPE=Release
cmake --build dr_libs/build --config Release