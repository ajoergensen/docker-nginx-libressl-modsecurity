#!/bin/bash
set -eu

declare -A aliases
aliases=(
	[stable]='1.10'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
base=jessie

versions=( */ )
versions=( "${versions[@]%/}" )

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

cat <<-EOH
# this file is generated via https://github.com/nginx-modules/docker-nginx-libressl/blob/$(fileCommit "$self")/$self

Maintainers: Denis Denisov <denji0k@gmail.com> (@denji)
GitRepo: https://github.com/nginx-modules/docker-nginx-libressl.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	commit="$(dirCommit "$version/$base")"

	fullVersion="$(git show "$commit":"$version/$base/Dockerfile" | awk '$1 == "ENV" && $2 == "NGINX_VERSION" { print $3; exit }')"
	fullVersion="${fullVersion%[.-]*}"

	versionAliases=( $fullVersion )
	if [ "$version" != "$fullVersion" ]; then
		versionAliases+=( $version )
	fi
	versionAliases+=( ${aliases[$version]:-} )

	echo
	cat <<-EOE
		Tags: $(join ', ' "${versionAliases[@]}")
		GitCommit: $commit
		Directory: $version/$base
	EOE
done