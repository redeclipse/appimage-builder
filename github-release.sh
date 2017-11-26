#! /bin/bash
# Portions of this script from https://github.com/probonopd/uploadtool Copyright 2016 Simon Peter under the MIT License

RELEASE_NAME=appimage_continuous_$BRANCH

[ -n "$REPO_SLUG" ] || ( echo "No repo slug"; exit 1 )
[ -n "$GITHUB_TOKEN" ] || ( echo "No github token"; exit 1 )

echo "Releasing..."

clear_tmp() {
    # Info regarding temporary release that already exists.
    old_tmp_releaseurl="https://api.github.com/repos/$REPO_SLUG/releases/tags/$RELEASE_NAME.tmp"
    echo "Getting the release ID..."
    echo "old_tmp_releaseurl: $old_tmp_releaseurl"
    old_tmp_releaseinfos=$(curl -XGET --header "Authorization: token ${GITHUB_TOKEN}" "${old_tmp_releaseurl}")
    echo "old_tmp_releaseinfos: $old_tmp_releaseinfos"
    old_tmp_releaseid=$(echo "$old_tmp_releaseinfos" | jq -r '.id')

    # Delete release if required.
    if [ x"$old_tmp_releaseid" != "x" ]; then
        delete_url="https://api.github.com/repos/$REPO_SLUG/releases/$old_tmp_releaseid"
        echo "Deleting the release..."
        echo "delete_url: $delete_url"
        curl -XDELETE \
            --header "Authorization: token ${GITHUB_TOKEN}" \
            "${delete_url}"
    fi

    # Delete tag
    echo "Deleting the tag..."
    delete_url="https://api.github.com/repos/$REPO_SLUG/git/refs/tags/$RELEASE_NAME.tmp"
    echo "delete_url: $delete_url"
    curl -XDELETE \
        --header "Authorization: token ${GITHUB_TOKEN}" \
        "${delete_url}"
}

clear_tmp

# Create the release.
release_infos=$(curl -H "Authorization: token ${GITHUB_TOKEN}" --data '{"tag_name": "'"$RELEASE_NAME.tmp"'","target_commitish": "'"master"'","name": "'"Temp:$PLATFORM_BUILD"'","body": "'"Temporary release while uploading build $PLATFORM_BUILD."'","draft": false, "prerelease": true}' "https://api.github.com/repos/$REPO_SLUG/releases")
echo "$release_infos"
release_id=$(echo "$release_infos" | jq -r '.id')

# Get the upload url, should use URI Templates here.
upload_url="https://uploads.github.com/repos/$REPO_SLUG/releases/$release_id/assets"
echo "upload_url: $upload_url"

release_url=$(echo "$release_infos" | jq -r '.url')
echo "release_url: $release_url"

pushd out
# Create the zsync files...
echo "Running zsyncmake"
for FILE in *.AppImage; do
    if [ -e "$FILE" ]; then
        zsyncmake -o "$FILE.zsync" "$FILE"
    fi
done

# Upload the AppImages and zsync files...
echo "Uploading files"
for FILE in *; do
    if [ -e "$FILE" ]; then
        FULLNAME="${FILE}"
        BASENAME="$(basename "${FILE}")"
        echo "Uploading: $BASENAME"
        curl -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.manifold-preview" \
            -H "Content-Type: application/octet-stream" \
            --data-binary @$FULLNAME \
            "$upload_url?name=$BASENAME" | tee /dev/null
    fi
done
popd

# Info regarding release that already exists.
old_release_url="https://api.github.com/repos/$REPO_SLUG/releases/tags/$RELEASE_NAME"
echo "Getting the release ID..."
echo "old_release_url: $old_release_url"
old_release_infos=$(curl -XGET --header "Authorization: token ${GITHUB_TOKEN}" "${old_release_url}")
echo "old_release_infos: $old_release_infos"
old_release_id=$(echo "$old_release_infos" | jq -r '.id')

# Delete release if required.
if [ x"$old_release_id" != "x" ]; then
    delete_url="https://api.github.com/repos/$REPO_SLUG/releases/$old_release_id"
    echo "Deleting the release..."
    echo "delete_url: $delete_url"
    curl -XDELETE \
        --header "Authorization: token ${GITHUB_TOKEN}" \
        "${delete_url}"
fi

# Delete tag
echo "Deleting the tag..."
delete_url="https://api.github.com/repos/$REPO_SLUG/git/refs/tags/$RELEASE_NAME"
echo "delete_url: $delete_url"
curl -XDELETE \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    "${delete_url}"

# Finish the release.
release_infos=$(curl -H "Authorization: token ${GITHUB_TOKEN}" --data '{"draft": false, "name": "'"Continuous build: $BRANCH"'","body": "'"AppImages built from the \`$BRANCH\` branch.\n\n* [How to use these AppImages](https://redeclipse.net/wiki/How_to_Install_Red_Eclipse#AppImage)\n* [About the AppImage format and project](https://appimage.org)\n\nThe \`.zsync\` files are used automatically for update information."'","tag_name": "'"$RELEASE_NAME"'"}' "$release_url")
echo "$release_infos"

clear_tmp
