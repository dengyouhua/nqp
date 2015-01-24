# vi: filetype=perl6:
sub comment($comment) {
    say("# $comment");
}
sub constant($name, $value) {
    say("$name = $value");
}

sub stage_path($stage) {
    '$(JS_STAGE' ~ $stage ~ ')/';
}

sub make_parents($path) {
    my $parts := nqp::split("/",$path);
    nqp::pop($parts);
    '$(MKPATH) ' ~ nqp::join('/',$parts);
}

sub rule($target, $source, *@actions) {
    my $rule := "$target: $source\n";
    for @actions -> $action {
        if $rule ne '' {
            $rule := $rule ~ "\t$action\n";
        }
    }
    say($rule);
    $target;
}

sub nqp($prefix, $file, $stage, :$deps=[]) {
    my $source := $prefix ~ '/' ~ $file ~ '.nqp';
    my $path := stage_path($stage);
    my $mbc := $path ~ $file ~ '.moarvm';

    my $installed_pbc := 'gen/moar/stage2/' ~ $file ~ '.moarvm';

    nqp::unshift($deps, $source);

    rule($mbc, nqp::join(' ', $deps),
        make_parents($mbc),
        "\$(JS_NQP) --module-path=\$(JS_STAGE1) --target=mbc --output=$mbc $source",
        # HACK - workaround for not being able to supply multiple directories to --module-path
        make_parents($installed_pbc),
        "\$(CP) $mbc $installed_pbc"
    );
}

sub deps($target, *@deps) {
    say("$target : {nqp::join(' ',@deps)}");
}

sub combine(:$sources, :$stage, :$file, :$gen-version = 0) {

    my $target := stage_path($stage) ~ $file;
    my $version := stage_path($stage) ~ 'nqp-config.nqp';

    rule($target, $sources,
        make_parents($target),
        $gen-version ?? "\$(PERL) tools/build/gen-version.pl > $version" !! '',
        "\$(PERL) tools/build/gen-cat.pl js $sources {$gen-version ?? $version !! ''} > $target"
    ); 
}

sub cross-compile(:$stage, :$source, :$target, :$setting, :$no-regex-lib, :$deps = []) {
    my $path := stage_path($stage);
    my $moarvm := $path ~ $target ~ '.moarvm';
    # todo dependency on compiler
    
    nqp::unshift($deps, $source);
    nqp::unshift($deps, '$(JS_STAGE1_COMPILER)');

    rule($moarvm, nqp::join(' ', $deps), 
        make_parents($moarvm),

	"\$(JS_NQP) --module-path gen/js/stage1 src/vm/js/bin/cross-compile.nqp --setting=NULL --target=mbc --output $moarvm $source > node_modules/$target.js"

#	"\$(JS_NQP) src/vm/js/bin/cross-compile.nqp $source $path $target $setting $no-regex-lib",
        );
}


comment("This is the JS Makefile - autogenerated by gen-makefile.nqp");

constant('JS_BUILD_DIR','gen/js');
constant('JS_STAGE1','$(JS_BUILD_DIR)/stage1');
constant('JS_STAGE2','$(JS_BUILD_DIR)/stage2');
constant('JS_NQP','./$(M_RUNNER)$(BAT)');
#constant('JS_PARROT','$(PARROT_BIN_DIR)/parrot$(EXE) $(PARROT_ARGS)');

say('js-runner-default: js-all');

my $stage1-qast-compiler-moar := nqp('src/vm/js','QAST/Compiler',1);
my $stage1-hll-backend-moar := nqp('src/vm/js','HLL/Backend',1,:deps([$stage1-qast-compiler-moar]));

constant('JS_STAGE1_COMPILER',"$stage1-qast-compiler-moar $stage1-hll-backend-moar");


my $nqp-mo-combined := combine(:stage(2), :sources('$(NQP_MO_SOURCES)'), :file('$(NQP_MO_COMBINED)'));

my $nqp-mo-moarvm := cross-compile(:stage(2), :source($nqp-mo-combined), :target('nqpmo'), :setting('NULL'), :no-regex-lib(1));

#
#my $nqpcore-combined := combine(:stage(2), :sources('$(CORE_SETTING_SOURCES)'), :file('$(CORE_SETTING_COMBINED).nqp'));
#my $nqpcore-pbc := cross-compile(:stage(2), :source($nqpcore-combined), :target('NQPCORE.setting'), :setting('NULL'), :no-regex-lib(1), :deps([$nqp-mo-pbc]));
#
#my $QASTNode-combined := combine(:stage(2), :sources('$(QASTNODE_SOURCES)'), :file('$(QASTNODE_COMBINED)'));
#my $QASTNode-pbc := cross-compile(:stage(2), :source($QASTNode-combined), :target('QASTNode'), :setting('NQPCORE'), :no-regex-lib(1), :deps([$nqpcore-pbc]));
#
#my $QRegex-combined := combine(:stage(2), :sources('$(QREGEX_SOURCES)'), :file('$(QREGEX_COMBINED)'));
#my $QRegex-pbc := cross-compile(:stage(2), :source($QRegex-combined), :target('QRegex'), :setting('NQPCORE'), :no-regex-lib(1), :deps([$nqpcore-pbc, $QASTNode-pbc]));
#
#my $QAST-Compiler-pbc := cross-compile(:stage(2), :source('src/vm/js/QAST/Compiler.nqp'), :target('QAST/Compiler'), :setting('NQPCORE'), :no-regex-lib(0), :deps([$nqpcore-pbc, $QASTNode-pbc]));
#
#my $NQPHLL-combined := combine(:stage(2), :sources('src/vm/js/HLL/Backend.nqp $(COMMON_HLL_SOURCES)'), :file('$(HLL_COMBINED)')); 
#my $NQPHLL-pbc := cross-compile(:stage(2), :source($NQPHLL-combined), :target('NQPHLL'), :setting('NQPCORE'), :no-regex-lib(1), :deps([$nqpcore-pbc, $QAST-Compiler-pbc]));
#
#my $QAST-pbc := cross-compile(:stage(2), :source('src/vm/js/QAST.nqp'), :target('QAST'), :setting('NQPCORE'), :no-regex-lib(1), :deps([$nqpcore-pbc, $QASTNode-pbc]));
#
#my $NQPP6QRegex-combined := combine(:stage(2), :sources('$(P6QREGEX_SOURCES)'), :file('$(P6QREGEX_COMBINED)')); 
#my $NQPP6QRegex-pbc := cross-compile(:stage(2), :source($NQPP6QRegex-combined), :target('NQPP6QRegex'), :setting('NQPCORE'), :no-regex-lib(1), :deps([$nqpcore-pbc, $QRegex-pbc, $NQPHLL-pbc, $QAST-pbc]));
#
#
#my $NQP-combined := combine(:stage(2), :sources('$(COMMON_NQP_SOURCES)'), :file('$(NQP_COMBINED)'), :gen-version(1));
#
#say("nqp-js.js: $nqpcore-pbc $QASTNode-pbc $QRegex-pbc $NQPP6QRegex-pbc $NQP-combined
#	./nqp-js-compile gen/js/stage2/NQP.nqp > nqp-js.js
#");
#
deps('js-stage1-compiler', '$(JS_STAGE1_COMPILER)');
##constant('JS_ALL'," $nqpcore-pbc $QASTNode-pbc $QRegex-pbc $NQPP6QRegex-pbc $NQP-combined");
#
##deps("js-all", 'p-all', 'js-stage1-compiler', '$(JS_ALL)', 'node_modules/installed');
#
## we don't have a proper runner yet but the Makefile structure requires that
#deps('js-runner-default', 'js-all');
#

say("node_modules/mini-setting.setting.js: \$(JS_STAGE1_COMPILER) src/vm/js/mini-setting $nqp-mo-moarvm
	\$(MKPATH) gen/js/stage2
	./nqp-m --module-path gen/js/stage1 src/vm/js/bin/cross-compile.nqp --module-path gen/js/stage2 --setting=NULL --target=mbc --output gen/js/stage2/mini-setting.setting.moarvm src/vm/js/mini-setting > node_modules/mini-setting.setting.js");

say('js-test: js-all
	src/vm/js/bin/run_tests');

say("\n\njs-clean:
	\$(RM_RF) gen/js/stage1 gen/js/stage2
");

deps("js-all", 'm-all', 'js-stage1-compiler', 'node_modules/installed','node_modules/mini-setting.setting.js');

# Enforce the google coding standards
say("js-lint:
	gjslint --strict --nojsdoc src/vm/js/nqp-runtime/*.js");

say('node_modules/installed: src/vm/js/nqp-runtime/*.js src/vm/js/nqp-runtime/package.json
	npm install src/vm/js/nqp-runtime
	touch node_modules/installed');
