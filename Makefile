e2e-test-setup:
	test/endtoend/get_deps.sh

migration-test-setup: e2e-test-setup
	echo "Setup Migration test"
	test/endtoend/migration_test.sh