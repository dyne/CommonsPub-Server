CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
FROM_BRANCH=flavour/commonspub

echo "This script helps merge updates into the current branch (${CUR_BRANCH}) from another branch, while preserving local customisations"

echo "What branch do you want to merge from? Press 'd' and enter if you want to use the default (${FROM_BRANCH}), otherwise enter the branch name:"
read answer
if echo "$answer" | grep -iq "^d" ; then
    echo "Ok..."
else
    FROM_BRANCH=$answer
fi

echo "Updating ${FROM_BRANCH} branch from origin"
git checkout ${FROM_BRANCH}
git pull

echo "Going back to the target ${CUR_BRANCH} branch"
git checkout ${CUR_BRANCH}

echo "Merging, without commiting yet"
git merge --no-ff --no-commit ${FROM_BRANCH}

echo "Restoring files which we don't want overwritten (add any core files that should be different in each flavour to the below line in the script)"
for file in README.md *.reflow config/deployment/etc/tor/torrc
do
    git reset HEAD ${file}
    git checkout -- ${file}
done

echo "Please check if everything looks good (including resolving any merge conflicts) before continuing. Press 'c' to merge and push the changes, or just enter to abort."
read answer
if echo "$answer" | grep -iq "^c" ; then
    echo "Merging and pushing..."
    git commit -m "merged from ${FROM_BRANCH}"
    git push
else 
    echo "Aborting the merge."
    git merge --abort
    exit 1
fi