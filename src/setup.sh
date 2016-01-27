#!/bin/sh

sudo apt-get install phantomjs nodejs nodejs-legacy npm -y
sudo npm install phantom -g
sudo npm install phantom
sudo apt-get install opam gcc nasm -y

cd ../tests/
sudo npm install phantom
cd ../libparse/Test/
sudo npm install phantom
cd ../../src/

make
cp ted ../libparse/Test/
