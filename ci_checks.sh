#!/bin/bash

# This script performs a set of checks on a Go package and its sub-packages:
#
#    1. gofmt         (http://golang.org/cmd/gofmt/)
#    2. goimports     (http://godoc.org/golang.org/x/tools/cmd/goimports)
#    3. golint        (https://github.com/golang/lint)
#    4. revive        (https://github.com/mgechev/revive)
#    5. go vet        (http://golang.org/cmd/vet)
#    6. go test       (https://golang.org/cmd/go/#hdr-Test_packages)
#    7. race detector (http://blog.golang.org/race-detector)
#    8. test coverage (http://blog.golang.org/cover, https://github.com/mattn/goveralls)
#    9. GolangCI-Lint (https://github.com/golangci/golangci-lint)

echo "### gofmt"
test -z "$(find . -type f -name '*.go' -print0 | xargs -0 gofmt -l -s  | tee /dev/stderr)"
GOFMT_FAIL=$?
echo

echo "### goimports"
test -z "$(find . -type f -name '*.go' -print0 | xargs -0 goimports -l  | tee /dev/stderr)"
GOIMPORTS_FAIL=$?
echo

if [ -f .revive.toml ]; then
	echo "### revive"
	test -z "$(revive -config .revive.toml ./... | tee /dev/stderr)"
	REVIVE_FAIL=$?
	echo
else
	echo "### golint"
	test -z "$(golint ./... | tee /dev/stderr)"
	GOLINT_FAIL=$?
	echo
fi

echo "### go vet"
go vet ./...
GOVET_FAIL=$?
echo

echo "### go test"
go test ./...
GOTEST_FAIL=$?
echo

echo "### go test -race"
go test -race ./...
GOTEST_RACE_FAIL=$?
echo

if [ "${COVERALLS_TOKEN}" ]; then
	echo "### go tool cover"
	go test -covermode=count -coverprofile=coverage.out ./...
	go tool cover -func coverage.out

	# To submit the test coverage result to coveralls.io use goveralls
	# (https://github.com/mattn/goveralls)
	goveralls -coverprofile coverage.out -service travis-ci -repotoken ${COVERALLS_TOKEN}
fi

GOLANGCI_LINT_FAIL=0
if [ -x "$(command -v golangci-lint)" ]; then
	echo "### GolangCI-Lint"
	golangci-lint run --enable-all
	GOLANGCI_LINT_FAIL=$?
	echo
fi

RET=0
if [ ${GOFMT_FAIL} -eq 1 ]; then
	echo "gofmt:         FAIL"
	RET=1
else
	echo "gofmt:         PASS"
fi
if [ ${GOIMPORTS_FAIL} -eq 1 ]; then
	echo "goimports:     FAIL"
	RET=1
else
	echo "goimports:     PASS"
fi
if [ -f .revive.toml ]; then
	if [ ${REVIVE_FAIL} -eq 1 ]; then
		echo "revive:        FAIL"
		# We do consider a revive lint failure a CI failure, since we can disable
		# specific rules using the .revive.toml config.
		RET=1
	else
		echo "revive:        PASS"
	fi
else
	if [ ${GOLINT_FAIL} -eq 1 ]; then
		echo "golint:        FAIL"
		# We don't consider a golint failure a CI failure.
		#RET=1
	else
		echo "golint:        PASS"
	fi
fi
if [ ${GOVET_FAIL} -eq 1 ]; then
	echo "go vet:        FAIL"
	RET=1
else
	echo "go vet:        PASS"
fi
if [ ${GOTEST_FAIL} -eq 1 ]; then
	echo "go test:       FAIL"
	RET=1
else
	echo "go test:       PASS"
fi
if [ ${GOTEST_RACE_FAIL} -eq 1 ]; then
	echo "go test -race: FAIL"
	RET=1
else
	echo "go test -race: PASS"
fi
if [ ${GOLANGCI_LINT_FAIL} -eq 1 ]; then
	echo "GolangCI-Lint: FAIL"
	# We don't consider a Golang-CI lint failure a CI failure.
	#RET=1
else
	echo "GolangCI-Lint: PASS"
fi
echo "ret: ${RET}"
exit ${RET}
