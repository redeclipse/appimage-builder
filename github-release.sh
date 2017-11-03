#! /bin/bash
# Portions of this script from https://github.com/probonopd/uploadtool Copyright 2016 Simon Peter under the MIT License

REPO_SLUG=red-eclipse/deploy
RELEASE_NAME=appimage_continuous_$BRANCH

[ -n "$GITHUB_TOKEN" ] || ( echo "No github token"; exit 1 )

# Info regarding release that already exists.
release_url="https://api.github.com/repos/$REPO_SLUG/releases/tags/$RELEASE_NAME"
echo "Getting the release ID..."
echo "release_url: $release_url"
release_infos=$(curl -XGET --header "Authorization: token ${GITHUB_TOKEN}" "${release_url}")
echo "release_infos: $release_infos"
release_id=$(echo "$release_infos" | jq -r '.id')

echo "Releasing..."

# Delete release if required.
if [ x"$release_id" != "x" ]; then
    delete_url="https://api.github.com/repos/$REPO_SLUG/releases/$release_id"
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

# Create the release.
release_infos=$(curl -H "Authorization: token ${GITHUB_TOKEN}" --data '{"tag_name": "'"$RELEASE_NAME"'","target_commitish": "'"$BRANCH"'","name": "'"Continuous build"'","draft": false, "prerelease": true}' "https://api.github.com/repos/$REPO_SLUG/releases")
echo "$release_infos"
release_id=$(echo "$release_infos" | jq -r '.id')

# Get the upload url, should use URI Templates here.
upload_url="https://uploads.github.com/repos/shacknetisp/test-deploy-repo/releases/$release_id/assets"
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

# Finish the release.
release_infos=$(curl -H "Authorization: token ${GITHUB_TOKEN}" --data '{"draft": false}' "$release_url")
echo "$release_infos"
