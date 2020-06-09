#!/bin/bash

mypathglibc=${GENTOO_GLIBC_REPO:-~/Gentoo/misc/glibc}
mypathpatches=${GENTOO_GLIBC_PATCHES_REPO:-~/Gentoo/misc/glibc-patches}

# I plan to extend this script a bit, to also help with the initial
# Gentoo release branch creation. That's why I check so much for both
# git repos... -A

PN="glibc"
PV=${1%/}
pver=$2

if [[ -z ${PV} ]] ; then
	echo "Usage: $0 glibc-version patchset-version-to-be-created"
	echo "Important environment variables: GENTOO_GLIBC_REPO GENTOO_GLIBC_PATCHES_REPO"
	echo "Please read the script before trying to use it :)"
	exit 1
fi

# check that we have a gentoo glibc patches git repo

if [[ ! -f "${mypathpatches}/README.Gentoo.patches" ]] || [[ ! -d "${mypathpatches}/.git" ]] ; then
	echo "Error: GENTOO_GLIBC_PATCHES_REPO needs to point to the main directory of a Gentoo glibc patchset git clone"
	exit 1
fi

# check that we have a gentoo glibc git repo

if [[ ! -f "${mypathglibc}/libc-abis" ]] || [[ ! -d "${mypathglibc}/.git" ]] ; then
	echo "Error: GENTOO_GLIBC_REPO needs to point to the main directory of a Gentoo glibc git clone"
	exit 1
fi

# go into the gentoo patches repo

cd "${mypathpatches}"

# check that the working directory is clean

mystatusinfo=$(git status --porcelain)
if [[ ! -z "${mystatusinfo}" ]] ; then
	echo "Error: Your glibc patches working directory is not clean"
	exit 1
fi

mydescpatches=$(git describe)

# go into the gentoo glibc repo

cd "${mypathglibc}"

# check that we're on a branch gentoo/${PV}

mybranchinfo=$(git status --porcelain -b|grep '^##')
mybranch=$(echo ${mybranchinfo}|sed -e 's:^## ::' -e 's:\.\.\..*$::')
if [[ ! "gentoo/${PV}" == "${mybranch}" ]] ; then
	echo "Error: Your glibc git repository is on the incorrect branch ${mybranch}; should be gentoo/${PV}"
	exit 1
fi

# check that the working directory is clean

mystatusinfo=$(git status --porcelain)
if [[ ! -z "${mystatusinfo}" ]] ; then
	echo "Error: Your glibc working directory is not clean"
	exit 1
fi

mydescglibc=$(git describe)

# check if the tag already exists

mytaginfo=$(git tag -l|grep "gentoo/glibc-${PV}-${pver}")
if [[ ! -z "${mytaginfo}" ]] ; then
	echo "Error: A tag corresponding to this patch level already exists (gentoo/glibc-${PV}-${pver})"
	exit 1
fi

# luckily glibc git has no /tmp dir and no tar.xz files, but let's better check and be pathologically careful

if [[ -e tmp ]] || [[ -e ${PN}-${PV}-patches-${pver}.tar.xz ]] ; then
	echo "Error: tmp or ${PN}-${PV}-patches-${pver}.tar.xz exists in git"
	exit 1
fi
rm -rf tmp
rm -f ${PN}-${PV}-*.tar.xz

for myname in 0*.patch ; do
	if [[ -e ${myname} ]]; then
		echo "Error: ${myname} exists in git"
		exit 1
	fi
done
rm -f 0*.patch

mkdir -p tmp/patches

# copy README.Gentoo.patches

cp "${mypathpatches}/README.Gentoo.patches" tmp/ || exit 1

echo >> "tmp/README.Gentoo.patches"
echo "Generated with make-tarball.sh ${mydescpatches}" >> "tmp/README.Gentoo.patches"

# create and rename patches

if [[ "${PV}" == "9999" ]]; then
	# working with master is not supported anymore
	echo "Patchsets for git master are not supported anymore"
    exit 1
else
	# release branch, start from upstream release tag
	startpoint="glibc-${PV}"
fi

git format-patch ${startpoint}..HEAD > /dev/null

# remove all patches where the summary line starts with [no-tarball] or [no-patch]
# this should not be needed anymore (no such commits), we can remove it once we're sure

rm -f 0???-no-tarball-*.patch
rm -f 0???-no-patch-*.patch

# move patches into temporary directory

mv 0*.patch tmp/patches/ || exit 1

# add a history file

git log --stat --decorate ${startpoint}..HEAD > tmp/patches/README.history || exit 1

# package everything up

tar -Jcf ${PN}-${PV}-patches-${pver}.tar.xz \
	-C tmp patches README.Gentoo.patches || exit 1
rm -r tmp

du -b *.tar.xz

# tag the commit

git tag -s -m "Gentoo patchset ${PV}-${pver}" "gentoo/glibc-${PV}-${pver}"
