#!/bin/bash

source ./test/endtoend/utils.sh

checkKeyspaceServing main-test - 1 || exit 1