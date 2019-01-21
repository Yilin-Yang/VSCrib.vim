#!/bin/bash

# EFFECTS:  Runs all test cases in this folder, using this directory's
#           localvimrc as well as neovim.
# DETAILS:  Taken, in part, from:
#               https://github.com/junegunn/vader.vim
#               https://github.com/neovim/neovim/issues/4842
# PARAM:    TEST_INTERNATIONAL  If set to '-i' or '--international', re-run
#                               tests in non-English locales.
printUsage() {
  echo "USAGE: ./run_tests.sh [--vim | --neovim] [-v|--visible] [-h|--help] [-i|--international] [-f <FILE_PAT> | --file=<FILE_PAT>]"
  echo ""
  echo "Run test cases for this plugin."
  echo ""
  echo "Arguments:"
  printf "\t--vim | --neovim    Whether to run tests using vim or neovim\n"
  printf "\t-v, --visible       Whether to run tests in an interactive vim instance\n"
  printf "\t-h, --help           Print this helptext\n"
  printf "\t-i, --international  Re-run tests using non-English locales\n"
  printf "\t-f <PAT>, --file=<PAT>   Run only tests globbed (matched) by <PAT>\n"
}

BASE_CMD_NVIM="nvim --headless -Nnu .test_vimrc -i NONE"
BASE_CMD_VIM="vim -Nnu .test_vimrc -i NONE"
RUN_VIM=1
VISIBLE=0
VADER_CMD="-c 'Vader!"
TEST_PAT=" test-*.vader'"
for ARG in "$@"; do
  case $ARG in
    '-i' | '--international')
      TEST_INTERNATIONAL=1
      ;;
    '-v' | '--visible')
      VISIBLE=1
      BASE_CMD_NVIM="nvim -Nnu .test_vimrc -i NONE"
      BASE_CMD_VIM="vim -Nnu .test_vimrc -i NONE"
      VADER_CMD="-c 'Vader"
      ;;
    '--vim')
      RUN_VIM=1
      ;;
    '--neovim')
      RUN_VIM=0
      ;;
    "--file="*)
      TEST_PAT="${ARG#*=}'"
      ;;
    "-f")
      shift
      TEST_PAT="${ARG#*=}'"
      ;;
    "-h")
      printUsage
      exit 0
      ;;
    "--help")
      printUsage
      exit 0
      ;;
    esac
  done
export IS_VSCRIB_DEBUG=1

set -p
export VADER_OUTPUT_FILE=/dev/stderr
if [ $RUN_VIM -ne 0 ]; then
  BASE_CMD=$BASE_CMD_VIM
  if [ $VISIBLE -eq 0 ]; then
    TEST_PAT="$TEST_PAT > /dev/null"
  fi
else
  BASE_CMD=$BASE_CMD_NVIM
fi
echo "${BASE_CMD} ${VADER_CMD} ${TEST_PAT}"
eval "${BASE_CMD} ${VADER_CMD} ${TEST_PAT}"

if [ $TEST_INTERNATIONAL ]; then
  # test non-English locale
  eval "${BASE_CMD} -c 'language de_DE.utf8' ${VADER_CMD} ${TEST_PAT}"
  eval "${BASE_CMD} -c 'language es_ES.utf8' ${VADER_CMD} ${TEST_PAT}"
fi
unset IS_VSCRIB_DEBUG
