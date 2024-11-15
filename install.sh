#!/bin/bash

#repo addresses
aasdkRepo="https://github.com/bismuthoxide7/aasdk"
gstreamerRepo="https://github.com/GStreamer/qt-gstreamer"
openautoRepo="https://github.com/openDsh/openauto"
h264bitstreamRepo="https://github.com/aizvorski/h264bitstream"
pulseaudioRepo="https://gitlab.freedesktop.org/pulseaudio/pulseaudio.git"

#Help text
display_help() {
    echo
    echo "   --deps           install all dependencies"
    echo "   --aasdk          install and build aasdk"
    echo "   --openauto       install and build openauto "
    echo "   --gstreamer      install and build gstreamer "
    echo "   --dash           install and build dash "
    echo "   --h264bitstream  install and build h264bitstream"
    echo "   --pulseaudio     install and build pulseaudio to fix raspberry pi bluetooth HFP"
    echo "   --bluez          install and build bluez to fix raspberry pi bluetooth outbound connection"
    echo "   --ofono          install and configure ofono to allow bluetooth HFP"
    echo "   --debug          create a debug build "
    echo
}

# Formerly checked Distro version, has been overridden
echo "Assumed Debian version of Bullseye or above"
BULLSEYE=true

#check if /etc/rpi-issue exists, if not set the install Args to be false
if [ -f /etc/rpi-issue ]
then
  rpiModel=$(awk '{print $3}' < /sys/firmware/devicetree/base/model)
  echo "Detected Raspberry Pi Model $rpiModel"
  installArgs="-DRPI_BUILD=true"
  isRpi=true
else
  installArgs=""
  isRpi=false
fi

#check for potential resource limit
totalMem=$(free -tm | awk '/Total/ {print $2}')
if [[ $totalMem -lt 1900 ]]; then
  echo "$totalMem MB RAM detected"
  echo "You may run out of memory while compiling with less than 2GB"
  echo "Consider raising swap space or compiling on another machine"
  echo "Installation will be attempted in 5 seconds"
  sleep 5;
fi

BUILD_TYPE="Release"

#check to see if there are any arguments supplied, if none are supplied run full install
if [ $# -gt 0 ]; then
  #initialize all arguments to false before looping to find which are available
  deps=false
  aasdk=false
  gstreamer=false
  openauto=false
  dash=false
  h264bitstream=false
  pulseaudio=false
  bluez=false
  ofono=false
    while [ "$1" != "" ]; do
        case $1 in
            --deps )           shift
                                    deps=true
                                    ;;
            --aasdk )           aasdk=true
                                    ;;
            --gstreamer )       gstreamer=true
                                    ;;
            --openauto )       openauto=true
                                    ;;
            --dash )           dash=true
                                    ;;
            --h264bitstream )  h264bitstream=true
                                    ;;
            --pulseaudio )     pulseaudio=true
                                    ;;
            --bluez )          bluez=true
                                    ;;
            --ofono )          ofono=true
                                    ;;
            --debug )          BUILD_TYPE="Debug"
                                    ;;
            -h | --help )           display_help
                                    exit
                                    ;;
            * )                     display_help
                                    exit 1
        esac
        shift
    done
else
    echo -e Full install running'\n'
    deps=true
    aasdk=true
    gstreamer=true
    openauto=true
    h264bitstream=true
    pulseaudio=true

script_path=$(dirname "$(realpath -s "$0")")
echo "Script directory is $script_path"

installArgs="-DCMAKE_BUILD_TYPE=${BUILD_TYPE} $installArgs"

#Array of dependencies any new dependencies can be added here
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


###############################  dependencies  #########################
if [ $deps = false ]
  then
    echo -e skipping dependencies '\n'
  else
    if [ $isDebian ] && [ $BULLSEYE = false ]; then
      echo Adding qt5-default to dependencies
      dependencies[${#dependencies[@]}]="qt5-default"
    fi

    echo installing dependencies
    #loop through dependencies and install
    echo Running apt-get update
    sudo apt-get update

    installString="sudo apt-get install -y "

    #create apt-get install string
    for i in ${dependencies[@]}; do
      installString+=" $i"
    done

    #run install
    ${installString}
    if [[ $? -eq 0 ]]; then
        echo -e All dependencies Installed ok '\n'
    else
        echo Package failed to install with error code $?, quitting check logs above
        exit 1
    fi
fi

############################### pulseaudio #########################
if [ $pulseaudio = false ]
  then
    echo -e skipping pulseaudio '\n'
  else
    #change to project root
    cd $script_path
    
    echo Preparing to compile and install pulseaudio
    echo Grabbing pulseaudio deps
    sudo sed -i 's/#deb-src/deb-src/g' /etc/apt/sources.list
    sudo apt-get update -y
    git clone $pulseaudioRepo
    sudo apt-get install -y autopoint
    cd pulseaudio
    git checkout tags/v12.99.3
    echo Applying imtu patch
    sed -i 's/*imtu = 48;/*imtu = 60;/g' src/modules/bluetooth/backend-native.c
    sed -i 's/*imtu = 48;/*imtu = 60;/g' src/modules/bluetooth/backend-ofono.c
    sudo apt-get build-dep -y pulseaudio
    ./bootstrap.sh
    make -j4
    sudo make install
    sudo ldconfig
    # copy configs and force an exit 0 just in case files are identical (we don't care but it will make pimod exit)
    sudo cp /usr/share/pulseaudio/alsa-mixer/profile-sets/* /usr/local/share/pulseaudio/alsa-mixer/profile-sets/
    cd ..
fi

###############################  AASDK #########################
if [ $aasdk = false ]; then
	echo -e Skipping aasdk '\n'
else
  #change to project root
  cd $script_path

  #clone aasdk
  git clone $aasdkRepo
  if [[ $? -eq 0 ]]; then
    echo -e Aasdk Cloned ok '\n'
  else
    cd aasdk
    if [[ $? -eq 0 ]]; then
      git pull $aasdkRepo
      echo -e Aasdk Cloned OK '\n'
      cd ..
    else
      echo Aasdk clone/pull error
      exit 1
    fi
  fi

  #change into aasdk folder
  echo -e moving to aasdk '\n'
  cd aasdk

  #apply set_FIPS_mode patch
  echo Apply set_FIPS_mode patch
  git apply $script_path/patches/aasdk_openssl-fips-fix.patch

  #create build directory
  echo Creating aasdk build directory
  mkdir build

  if [[ $? -eq 0 ]]; then
    echo -e aasdk build directory made
  else
    echo Unable to create aasdk build directory assuming it exists...
  fi

  cd build

  #beginning cmake
  cmake -DCMAKE_BUILD_TYPE=Release ../
  if [[ $? -eq 0 ]]; then
      echo -e Aasdk CMake completed successfully'\n'
  else
    echo Aasdk CMake failed with code $?
    exit 1
  fi

  #beginning make
  make -j2

  if [[ $? -eq 0 ]]; then
    echo -e Aasdk Make completed successfully '\n'
  else
    echo Aasdk Make failed with code $?
    exit 1
  fi

  #begin make install
  sudo make install

  if [[ $? -eq 0 ]]
    then
    echo -e Aasdk installed ok'\n'
    echo
  else
    echo Aasdk install failed with code $?
    exit 1
  fi
  cd $script_path
fi

############################### h264bitstream #########################
if [ $h264bitstream = false ]; then
	echo -e Skipping h264bitstream '\n'
else
  #change to project root
  cd $script_path

  #clone h264bitstream
  git clone $h264bitstreamRepo
  if [[ $? -eq 0 ]]; then
    echo -e h264bitstream Cloned ok '\n'
  else
    cd h264bitstream
    if [[ $? -eq 0 ]]; then
      git pull $h264bitstreamRepo
      echo -e h264bitstream Cloned OK '\n'
      cd ..
    else
      echo h264bitstream clone/pull error
      exit 1
    fi
  fi

  #change into folder
  echo -e moving to h264bitstream '\n'
  cd h264bitstream

  echo Auto-reconfigure project
  autoreconf -i

  if [[ $? -eq 0 ]]; then
    echo -e autoreconfed h264bitstream
  else
    echo Unable to autoreconf h264bitstream
    exit 1
  fi

  echo Configuring h264bitstream

  ./configure --prefix=/usr/local
  if [[ $? -eq 0 ]]; then
      echo -e h264bitstream configured successfully'\n'
  else
    echo h264bitstream configure failed with code $?
    exit 1
  fi

  #beginning make
  make

  if [[ $? -eq 0 ]]; then
    echo -e h264bitstream Make completed successfully '\n'
  else
    echo h264bitstream Make failed with code $?
    exit 1
  fi

  #begin make install
  sudo make install

  if [[ $? -eq 0 ]]
    then
    echo -e h264bitstream installed ok'\n'
    echo
  else
    echo h264bitstream install failed with code $?
    exit 1
  fi
  cd $script_path
fi

###############################  gstreamer  #########################
#check if gstreamer install is requested
if [ $gstreamer = true ]; then
  echo installing gstreamer

  #change to project root
  cd $script_path

  #clone gstreamer
  echo Cloning Gstreamer
  git clone $gstreamerRepo
  if [[ $? -eq 0 ]]; then
    echo -e Gstreamer cloned OK
  else
    cd qt-gstreamer
      if [[ $? -eq 0 ]]; then
        git pull $gstreamerRepo
        echo -e cloned OK '\n'
        cd ..
      else
        echo Gstreamer clone/pull error
        exit 1
      fi
  fi

  #change into newly cloned directory
  cd qt-gstreamer

  if [ $BULLSEYE = true ] || [ $JAMMY = true ]; then
    #apply 1.18 patch
    echo Applying qt-gstreamer 1.18 patch
    git apply $script_path/patches/qt-gstreamer-1.18.patch
  fi

  #apply greenline patch
  echo Apply greenline patch
  git apply $script_path/patches/greenline_fix.patch

  #apply atomic patch
  echo Apply atomic patch
  git apply $script_path/patches/qt-gstreamer_atomic-load.patch

  #create build directory
  echo Creating Gstreamer build directory
  mkdir build

  if [[ $? -eq 0 ]]; then
    echo -e Gstreamer build directory made
  else
    echo Unable to create Gstreamer build directory assuming it exists...
  fi

  cd build

  #run cmake
  echo Beginning cmake
  cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH) -DCMAKE_INSTALL_INCLUDEDIR=include -DQT_VERSION=5 -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-std=c++11

  if [[ $? -eq 0 ]]; then
    echo -e Make ok'\n'
  else
    echo Gstreamer CMake failed
    exit 1
  fi

  echo Making Gstreamer
  make

  if [[ $? -eq 0 ]]; then
    echo -e Gstreamer make ok'\n'
  else
    echo Make failed with error code $?
    exit 1
  fi

  #run make install
  echo Beginning make install
  sudo make install

  if [[ $? -eq 0 ]]; then
    echo -e Gstreamer installed ok'\n'
  else
    echo Gstreamer make install failed with error code $?
    exit 1
  fi

  sudo ldconfig
  cd $script_path

else
	echo -e Skipping Gstreamer'\n'
fi



###############################  openauto  #########################
if [ $openauto = false ]; then
  echo -e skipping openauto'\n'
else
  echo Installing openauto

  #change to project root
  cd $script_path

  #clone openauto
  echo -e cloning openauto'\n'
  git clone $openautoRepo
  if [[ $? -eq 0 ]]; then
    echo -e cloned OK'\n'
  else
    cd openauto
    if [[ $? -eq 0 ]]; then
      git pull $openautoRepo
      echo -e Openauto cloned OK'\n'
      cd ..
    else
      echo Openauto clone/pull error
      exit 1
    fi
  fi

  cd openauto

  #create build directory
  echo Creating openauto build directory
  mkdir build

  if [[ $? -eq 0 ]]; then
    echo -e openauto build directory made
  else
    echo Unable to create openauto build directory assuming it exists...
  fi

  cd build

  echo Beginning openauto cmake
  cmake ${installArgs} -DGST_BUILD=true ../
  if [[ $? -eq 0 ]]; then
    echo -e Openauto CMake OK'\n'
  else
    echo Openauto CMake failed with error code $?
    exit 1
  fi

  echo Beginning openauto make
  make

  if [[ $? -eq 0 ]]; then
    echo -e Openauto make OK'\n'
  else
    echo Openauto make failed with error code $?
    exit 1
  fi

  #run make install
  echo Beginning make install
  sudo make install
  if [[ $? -eq 0 ]]; then
    echo -e Openauto installed ok'\n'
  else
    echo Openauto make install failed with error code $?
    exit 1
  fi
  cd $script_path
fi
##############################################################
echo "Install Complete"
exit 0

