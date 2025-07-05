#import "Basic";
#import "Compiler";
#import "File";
#import "String";

#run {
    set_build_options_dc(.{do_output=false});
    make_directory_if_it_does_not_exist("./bin/");

    root_options := get_build_options();
    args := root_options.compile_time_command_line;
    import_path: [..] string;
    array_add(*import_path, .. root_options.import_path);
    array_add(*import_path, "./modules");

    release := array_find(args, "-release");
    release_very := array_find(args, "-very-release");

    ok: bool;
    {
        w := compiler_create_workspace("protonJai");
        options := get_build_options(w);
        copy_commonly_propagated_fields(get_build_options(), *options);
        options.output_executable_name = "protonJai";
        options.output_path = "./bin";
        if release set_optimization(*options, .OPTIMIZED);
        if release_very set_optimization(*options, .VERY_OPTIMIZED);
        set_build_options(options, w);

        add_build_file("./src/main.jai", w);
    }
}
