load 'test-lib'

teardown() {
    assert_test_home
}

# This is a spike just to test the integration of the passes.
#
@test "All together now!" {
    create_test_home <<.
        .home/AAA/bin/prog                  # directly linked
        .home/AAA/dot/config.inb4           # source file
        .home/BBB/dot/config.inb1           # source file
        .home/BBB/share/data.inb4           # data file not linked into $HOME
        .home/BBB/share/data.inb9
        .home/BBB/dh/update                 # updated below
        .home/AAA/dh/dependencies           # updated below
.
    sed -e 's/^        //'  >"$test_home/.home/BBB/share/data.inb9" <<.
        * A comment starting with specific text in the first five lines of
        * any inb4 fragment tells inb4 to use a different comment character:
        * :inb4:
.
    sed -e 's/^        //'  >"$test_home/.home/BBB/dh/update" <<.
        #!/usr/bin/env bash
        echo 'dh/update: Up to date!'
.
    chmod +x "$test_home/.home/BBB/dh/update"
    sed -e 's/^        //'  >"$test_home/.home/AAA/dh/dependencies" <<.

        # Comments and blank lines as usual in dependency files
        DEP-1 git $base_dir/t/fixtures/dependency 1.git
        BORK  borken
        AAA   ignored because already here
.
    # The `dh/dependencies` file in the DEP-1 test fixture uses this location:
    cp -r "$base_dir/t/fixtures/dependency 2.git" "$test_scratch_dir"

    # Add .local/bin to path to avert warning from clean_legacy_bin pass
    PATH=$HOME/.local/bin:$PATH run_setup_on_test_home -u
    rm -rf "$test_home"/.home/DEP-?/.git

    assert_success_and_diff_test_home_with <<.
        .local/bin/prog -> ../../.home/AAA/bin/prog         # direct link
        .local/share/data -> ../../.home/_inb4/share/data
        .home/,inb4/dot/config                              # built files
        .home/,inb4/share/data
        .home/_inb4/dot/config              # installed file (directly linked)
        .home/_inb4/share/data              # installed data file
        .config -> .home/_inb4/dot/config   # link to installed file
        .home/DEP-1/dh/dependencies
        .home/DEP-2/dot/file-from-dep2
        .file-from-dep2 -> .home/DEP-2/dot/file-from-dep2
.

    sed -e 's/^        //'  <<. | diff -u - "$test_home/.config"
        ##### This file was generated by inb4.

        ##### BBB/dot/config.inb1
        Content of .home/BBB/dot/config.inb1

        ##### AAA/dot/config.inb4
        Content of .home/AAA/dot/config.inb4
.

    # `.home/*/share/*` is not (yet) linked into `.local/share/`
    sed -e 's/^        //'  <<. | diff -u - "$test_home/.home/,inb4/share/data"
        ***** This file was generated by inb4.

        ***** BBB/share/data.inb4
        Content of .home/BBB/share/data.inb4

        ***** BBB/share/data.inb9
        * A comment starting with specific text in the first five lines of
        * any inb4 fragment tells inb4 to use a different comment character:
        * :inb4:
.

    trim_spec <<. | assert_output
        ===== AAA
        ===== BBB
        dh/update: Up to date!
        ===== BORK
        .home WARNING: Unknown dependency type: borken
        ===== DEP-1
        Cloning into 'DEP-1'...
        done.
        ===== BORK
        .home WARNING: Unknown dependency type: borken
        ===== DEP-2
        Cloning into 'DEP-2'...
        done.
        ===== BORK
        .home WARNING: Unknown dependency type: borken
.
}
