# vim: et sts=2 sw=2

set -ex

export ARTIFACTSDIR=$PWD/exported-artifacts

export PATH=$PATH:/sbin:/usr/sbin
export CURLOPTS="-x http://proxy.phx.ovirt.org:3128"
export TMPDIR=$PWD/tmp
export LIBGUESTFS_BACKEND=direct

prepare() {
  virt-host-validate || :

  mkdir "$TMPDIR"
  mkdir "$ARTIFACTSDIR"
}

build() {
  # Build the squashfs for a later export
  ./autogen.sh --with-tmpdir=/var/tmp

  # Add this jenkins job as a repository
  cat <<EOF >> data/ovirt-node-ng-image.ks

%post
cat > /etc/yum.repos.d/ovirt-node.repo <<__EOR__
[ovirt-node-3.6-nightly]
name=oVirt Node Next (Nightly)
baseurl=http://jenkins.ovirt.org/job/ovirt-node-ng_ovirt-3.6_build-artifacts-fc22-x86_64/lastSuccessfulBuild/artifact/exported-artifacts/
enabled=1
gpgcheck=0
__EOR__
%end
EOF

  sudo -E make squashfs
  sudo -E make rpm
  sudo -E make offline-installation-iso

  mv -fv \
    *manifest* \
    tmp.repos/RPMS/noarch/*.rpm \
    *.squashfs.img \
    *.iso \
    *.log \
    "$ARTIFACTSDIR/"
}

check() {
  sudo -E make check
  ln -fv \
    *.img \
    tests/*.xml \
    "$ARTIFACTSDIR/"

  ls -shal "$ARTIFACTSDIR/" || :
}

repofy() {
  pushd "$ARTIFACTSDIR/"
  createrepo .
  popd
}

prepare
build

repofy
