### dependencies #####
dependencies=(
    "alsa-utils"
    "cmake"
    "libboost-all-dev"
    "libusb-1.0-0-dev"
    "libssl-dev"
    "libprotobuf-dev"
    "protobuf-c-compiler"
    "protobuf-compiler"
    "libqt5multimedia5"
    "libqt5multimedia5-plugins"
    "libqt5multimediawidgets5"
    "qtmultimedia5-dev"
    "libqt5bluetooth5"
    "libqt5bluetooth5-bin"
    "qtconnectivity5-dev"
    "pulseaudio"
    "pulseaudio-module-bluetooth"
    "librtaudio-dev"
    "librtaudio6"
    "qml-module-qtquick2"
    "libglib2.0-dev"
    "libgstreamer1.0-dev"
    "gstreamer1.0-plugins-base-apps"
    "gstreamer1.0-plugins-bad"
    "gstreamer1.0-libav"
    "gstreamer1.0-alsa"
    "libgstreamer-plugins-base1.0-dev"
    "qtdeclarative5-dev"
    "libgstreamer-plugins-bad1.0-dev"
    "libunwind-dev"
    "qml-module-qtmultimedia"
    "libqt5serialbus5-dev"
    "libqt5serialbus5-plugins"
    "libqt5serialport5-dev"
    "libqt5websockets5-dev"
    "libqt5svg5-dev"
    "build-essential"
    "libtool"
    "autoconf"
    "ffmpeg"
  )
installString="sudo apt-get install -y "

for i in ${dependencies[@]}; do
    installString+=" $i"
done

################### AASKD ########################

sudo apt-get update
sudo apt-get -y install cmake build-essential git


git clone https://github.com/OpenDsh/aasdk

cd aasdk

git apply $script_path/patches/aasdk_openssl-fips-fix.patch

mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=Release ../
make -j2
sudo make install

echo AASDK installed'\n'

#################### Openauto ###################################
cd $script_path

echo starting Openauto install'\n'

sudo apt-get -y install cmake build-essential git

git clone https://github.com/OpenDsh/openauto

mkdir openauto_build
cd openauto_build

cmake -DCMAKE_BUILD_TYPE=Release -DRPI3_BUILD=TRUE -DAASDK_INCLUDE_DIRS="../aasdk/include" -DAASDK_LIBRARIES="../aasdk/lib/libaasdk.so" -DAASDK_PROTO_INCLUDE_DIRS="../aasdk" -DAASDK_PROTO_LIBRARIES="../aasdk/lib/libaasdk_proto.so" ../openauto

make -j2

sudo make install
