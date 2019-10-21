#!/bin/bash
set -x

COMMIT=$1
PRNUM=$2
TOKEN=$3

RESULT=`git show --format=email $1 | checkpatch.pl --no-tree -`
BODY_URL=https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PRNUM}/comments
CODE_URL=https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PRNUM}/comments

FOUND=0
MESSAGE=
REVIEW=()

#
# checkpatch.pl result format
# ---------------------------
#
# Template:
# ---------
#
# [WARNING/ERROR]: [message for code line]
# #[id]: FILE: [filename]:[line-number]
# +[code]
# [empty line]
#
# [WARNING/ERROR]: [message for commit itself]
#
# total: [n] erros, [n] warnings, [n] lines checked
#
# example:
# --------
#
# ERROR: xxxx
# #15: FILE: a.c:3:
# +int main() {
#
# ERROR: Missing Signed-off-by: line(s)
#
# total: ...
#

while read -r row
do
    # End of checkpatch.pl message
    if [[ "$row" =~ ^total: ]]; then
        break
    fi

    # Additional parsing is needed
    if [[ "$FOUND" == "1" ]]; then

        # The row is started with "#"
        if [[ "$row" =~ ^\# ]]; then
            # message for file

            # Split the string using ':' seperator
            IFS=':' read -r -a list <<< "$row"

            # Trim whitespace
            FILE=$(echo ${list[2]} | xargs)

            LINE=${list[3]}
        else
            # An empty line means the paragraph is over.
            if [[ -z $row ]]; then
                if [[ -z $FILE ]]; then
                    COMMENT="{ \"body\": \"$MESSAGE\" }"
                    curl $BODY_URL -s -H "Authorization: token ${GITHUB_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -X POST --data "$(cat <<EOF
{
    "body": ":warning: ${COMMIT} - ${MESSAGE}"
}
EOF
)"
                else
                    COMMENT="{ \"commit_id\": \"$COMMIT\", \"side\": \"right\", \"path\": \"$FILE\", \"line\": \"$LINE\", \"body\": \"$MESSAGE\" }"
                    echo "code comment: $COMMENT"
                    curl $CODE_URL -s -H "Authorization: token ${GITHUB_TOKEN}" \
                        -X POST --data "$(cat <<EOF
{
    "commit_id": "$COMMIT",
    "side": "RIGHT",
    "path": "${FILE}",
    "line": ${LINE},
    "body": "${MESSAGE}"
}
EOF
)"
                fi

                REVIEW+=($COMMENT)
                FOUND=0
                FILE=
                LINE=
            fi
        fi
    fi

    # Found warning or error paragraph
    if [[ "$line" =~ ^(WARNING|ERROR) ]]; then
        MESSAGE=$line
        FOUND=1
        FILE=
        LINE=
    fi

done <<<"$RESULT"
