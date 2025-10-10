# Vyos

## Build the vyos image

### First build ISO

https://docs.vyos.io/en/latest/contributing/build-vyos.html

```
cd ~
git clone -b current --single-branch https://github.com/vyos/vyos-build
cd vyos-build
docker build -t vyos/vyos-build:current docker
docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:current bash
sudo ./build-vyos-image --architecture amd64 --version trust generic
```

### Create docker image

https://docs.vyos.io/en/latest/installation/virtual/docker.html

```
cd ~
mkdir vyos && cd vyos
mkdir rootfs
sudo mount -o loop ../vyos-build/build/vyos-trust-generic-amd64.iso rootfs
sudo apt-get install -y squashfs-tools
mkdir unsquashfs
sudo unsquashfs -f -d unsquashfs/ rootfs/live/filesystem.squashfs
sudo tar -C unsquashfs -c . | docker import - vyos:1.5
sudo umount rootfs
cd ..
sudo rm -rf vyos
```

### Test it works

```
docker network create --ipv6 -d macvlan -o parent=eno2 --subnet 2001:db8::/64 --subnet 192.0.2.0/24 mynet
docker run -d --rm --name vyos --net mynet --privileged vyos:1.5 /sbin/init
docker exec -ti vyos vbash
```

