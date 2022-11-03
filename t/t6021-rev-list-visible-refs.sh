#!/bin/sh

test_description='git rev-list --visible-refs test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit_bulk --id=commit --ref=refs/heads/main 1 &&
	COMMIT=$(git rev-parse refs/heads/main) &&
	test_commit_bulk --id=tag --ref=refs/tags/lightweight 1 &&
	TAG=$(git rev-parse refs/tags/lightweight) &&
	test_commit_bulk --id=hidden --ref=refs/hidden/commit 1 &&
	HIDDEN=$(git rev-parse refs/hidden/commit)
'

test_expect_success 'invalid section' '
	echo "fatal: unsupported section for --visible-refs: unsupported" >expected &&
	test_must_fail git rev-list --visible-refs=unsupported 2>err &&
	test_cmp expected err
'

test_expect_success '--visible-refs without hiddenRefs' '
	git rev-list --visible-refs=transfer >out &&
	cat >expected <<-EOF &&
	$HIDDEN
	$TAG
	$COMMIT
	EOF
	test_cmp expected out
'

test_expect_success 'hidden via transfer.hideRefs' '
	git -c transfer.hideRefs=refs/hidden/ rev-list --visible-refs=transfer >out &&
	cat >expected <<-EOF &&
	$TAG
	$COMMIT
	EOF
	test_cmp expected out
'

test_expect_success '--all --not --visible-refs=transfer without hidden refs' '
	git rev-list --all --not --visible-refs=transfer >out &&
	test_must_be_empty out
'

test_expect_success '--all --not --visible-refs=transfer with hidden ref' '
	git -c transfer.hideRefs=refs/hidden/ rev-list --all --not --visible-refs=transfer >out &&
	cat >expected <<-EOF &&
	$HIDDEN
	EOF
	test_cmp expected out
'

test_expect_success '--visible-refs with --exclude' '
	git -c transfer.hideRefs=refs/hidden/ rev-list --exclude=refs/tags/* --visible-refs=transfer >out &&
	cat >expected <<-EOF &&
	$COMMIT
	EOF
	test_cmp expected out
'

for section in receive uploadpack
do
	test_expect_success "hidden via $section.hideRefs" '
		git -c receive.hideRefs=refs/hidden/ rev-list --visible-refs=receive >out &&
		cat >expected <<-EOF &&
		$TAG
		$COMMIT
		EOF
		test_cmp expected out
	'

	test_expect_success "--visible-refs=$section respects transfer.hideRefs" '
		git -c transfer.hideRefs=refs/hidden/ rev-list --visible-refs=$section >out &&
		cat >expected <<-EOF &&
		$TAG
		$COMMIT
		EOF
		test_cmp expected out
	'

	test_expect_success "--visible-refs=transfer ignores $section.hideRefs" '
		git -c $section.hideRefs=refs/hidden/ rev-list --visible-refs=transfer >out &&
		cat >expected <<-EOF &&
		$HIDDEN
		$TAG
		$COMMIT
		EOF
		test_cmp expected out
	'

	test_expect_success "--visible-refs=$section respects both transfer.hideRefs and $section.hideRefs" '
		git -c transfer.hideRefs=refs/tags/ -c $section.hideRefs=refs/hidden/ rev-list --visible-refs=$section >out &&
		cat >expected <<-EOF &&
		$COMMIT
		EOF
		test_cmp expected out
	'
done

test_done
