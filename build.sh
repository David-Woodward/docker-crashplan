#!/bin/bash

REPOSITORY=woodwarden/crashplan-headless

usage() {
    echo "
Usage: $(basename ${0}) [OPTION] [version]

-l, --latest        Apply ""latest"" tag in addition to the standard version tag

-n, --no-build      Do not build a new image - only push the most recent image (implies -p)

-p, --push          Push the image to the docker registry (default is not to push)


Version pattern/examples:
    <major>.<minor>.<build>[-type]
    0.1.1-beta
    0.1.2-rc1
    0.1.2
    (if not specified, use last version tag with an incremented build component - 0.1.#-beta)
"
}

docker_login() {
    if [ -z ${DOCKER_PASS} ]; then
        docker login -u "${DOCKER_USER:-woodwarden}"
    else
        docker login -u "${DOCKER_USER:-woodwarden}" -p "${DOCKER_PASS}"
    fi
}

git_tag_and_push() {
    echo "

The git repository should be updated to match the docker repository with commands similar to:
git tag -s \"v${cp_version}__${new_tag}\" -m \"Changes for CrashPlan version ${cp_version}\"
git push origin \"v${cp_version}__${new_tag}\"
"
}

LATEST=0
BUILD=1
PUSH=0

while [ $# -gt 0 ]
do
key="$1"

case $key in
    -h|--help|\?)
    usage
    exit 0
    ;;
    -l|--latest)
    LATEST=1
    shift
    ;;
    -n|--no-build)
    BUILD=0
    PUSH=1
    shift
    ;;
    -p|--push)
    PUSH=1
    shift
    ;;
    *)
    new_tag="${1}"
    shift
    ;;
esac
done

SOURCE="${BASH_SOURCE[0]}"
[ -h "${SOURCE}" ] && SOURCE=$(readlink "${SOURCE}")
SCRIPTDIR="$( cd "$(dirname "${SOURCE}")" >/dev/null 2>&1 && pwd )"

cp_version="$(sed -rn 's/^[^#].*CRASHPLAN_VERSION=(\S+).*/\1/p' "${SCRIPTDIR}/Dockerfile" | head -n 1)"

# Version pattern: v<crashplan version>__<image version>-<release type>
# Example: v6.9.2__0.1.1-beta
# Groups .......   ( 1= optional cp ver prefx ) (            3 = image version            )
# ..............    (   2 = cp version     )     (4=maj )  (5=min )  (6=bld )(   7 = -type   )
# ..............                                                               (   8=type   )
version_pattern='v?(([0-9]+\.[0-9]+\.[0-9]+)__)?(([0-9]+)\.([0-9]+)\.([0-9]+)(-([A-Za-z._-]+))?)'

last_tag="v${cp_version}__0.0.0"
last_ver='0.0.0'
last_major=0
last_minor=0
last_build=0
last_type=''

# Get the highest local image version number
while read -r cur_tag cur_ver cur_major cur_minor cur_build cur_type
do
    if [ ${cur_major} -gt ${last_major} ] || ([ ${cur_minor} -gt ${last_minor} ] && [ ${cur_major} -eq ${last_major} ]) || ([ ${cur_build} -gt ${last_build} ] && [ "${cur_major}.${cur_minor}" == "${last_major}.${last_minor}" ]); then
        last_tag=${cur_tag}
        last_ver=${cur_ver}
        last_major=${cur_major}
        last_minor=${cur_minor}
        last_build=${cur_build}
        last_type=${cur_type}
    fi
done < <(docker images --filter="reference=${REPOSITORY}:*" --format '{{.Tag}}' | grep -E "^${version_pattern}\$" | sed -rn "s/^${version_pattern}\$/\0 \3 \4 \5 \6 \7/p")

if [ -z ${new_tag} ]; then
    new_major="${last_major}"
    new_minor="${last_minor}"
    new_type="${last_type}"
    if [ "${BUILD}" == "1" ]; then
        new_build="$(expr ${last_build} + 1)"
        new_ver="${last_major}.${last_minor}.$(expr ${last_build} + 1)${last_type}"
    else
        new_build="${last_build}"
    fi
    new_ver="${new_major}.${new_minor}.${new_build}"
    new_tag="${new_ver}${new_type}"
else
    new_tag=${new_tag#v*}
    read new_ver new_major new_minor new_build new_type < <(echo ${new_tag} | sed -rn "s/^${version_pattern}\$/\3 \4 \5 \6 \7/p")
    [ -z ${new_ver} ] && echo "Invalid version pattern: ${new_tag}" && exit 1
fi

# Build a new image (legacy tag if an older version was specified)
if [ "${BUILD}" == "1" ]; then
    echo "Building image version ${cp_version}__${new_tag} for ${REPOSITORY} from \"${SCRIPTDIR}\" ..."
    echo ""
    echo "(Last version = ${last_tag})"
    echo ""

    if docker build "${SCRIPTDIR}" -t "${REPOSITORY}:v${cp_version}__${new_tag}"; then
        if [ "${LATEST}" == "1" ]; then
            docker tag "${REPOSITORY}:v${cp_version}__${new_tag}" "${REPOSITORY}:latest"
        elif [ ${new_major} -gt ${last_major} ] || ([ ${new_major} -eq ${last_major} ] && [ ${new_minor} -gt ${last_minor} ]); then
            docker tag "${REPOSITORY}:v${cp_version}__${new_tag}" "${REPOSITORY}:latest"
        else
            docker tag "${REPOSITORY}:v${cp_version}__${new_tag}" "${REPOSITORY}:legacy"
        fi

        if [ "${PUSH}" == "1" ]; then
            echo "Pushing image ${new_tag} to ${REPOSITORY} ..."
            docker_login
            docker push --disable-content-trust=false "${REPOSITORY}:v${cp_version}__${new_tag}"
            [ "${LATEST}" == "1" ] && docker push "${REPOSITORY}:latest"
            git_tag_and_push
        else
            echo
            echo "---- Image Storage Requirement Summary ----"
            echo
            docker image ls "${REPOSITORY}:v${cp_version}__${new_tag}" --format '{{.Repository}}:{{.Tag}} = {{.Size}}'
            echo
            docker run -it --rm "${REPOSITORY}:v${cp_version}__${new_tag}" 'du -sh /*/ --exclude ''/proc/*'''
        fi
    fi
elif [ "${PUSH}" == "1" ]; then
    echo "Pushing image ${new_tag} to ${REPOSITORY} ..."
    docker_login
    docker push --disable-content-trust=false "${REPOSITORY}:v${cp_version}__${new_tag}"
    [ "${LATEST}" == "1" ] && docker tag "${REPOSITORY}:v${cp_version}__${new_tag}" "${REPOSITORY}:latest" && docker push "${REPOSITORY}:latest"
    git_tag_and_push
fi
