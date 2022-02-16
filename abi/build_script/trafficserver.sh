# Really only needed for GitHub checkout
autoreconf -if

# abi-dumper wants to have -Og optimization
sed -i -e 's/-O3/-Og/' configure

# Configure, build and install
./configure --prefix="$INSTALL_TO"
make -j 8
make -j 8 install

# Hacky cleanups
cp $INSTALL_TO/bin/traffic_server $INSTALL_TO/lib/traffic_server.so
rm -f $INSTALL_TO/lib/plugin*
