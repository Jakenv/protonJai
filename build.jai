#import "Basic";
#import "Compiler";
#import "File";

#run {
    set_build_options_dc(.{do_output=false});
    make_directory_if_it_does_not_exist("./bin/");

    root_options := get_build_options();
    args := root_options.compile_time_command_line;

    ok: bool;
    {
        w := compiler_create_workspace("protonJai");
        options := get_build_options(w);
        copy_commonly_propagated_fields(get_build_options(), *options);
        options.output_executable_name = "protonJai";
        options.output_path = "./bin";

        set_build_options(options, w);

        tracy: *Metaprogram_Plugin;
        flags: Intercept_Flags;
        if tracy && tracy.before_intercept tracy.before_intercept(tracy, *flags);

        compiler_begin_intercept(w, flags);
        if tracy && tracy.add_source tracy.add_source(tracy);
        add_build_file("./src/main.jai", w);
        ok = message_loop(w, args, tracy);
        compiler_end_intercept(w);

        if tracy && tracy.finish tracy.finish(tracy);
        if tracy && tracy.shutdown tracy.shutdown(tracy);
    }
}
message_loop :: (w: Workspace, args: []string, tracy: *Metaprogram_Plugin) -> bool {
    options := get_build_options(w);

    while true {
        message := compiler_wait_for_message();
        if tracy && tracy.message tracy.message(tracy, message);
        if message.kind != .COMPLETE continue;

        complete := cast(*Message_Complete) message;
        if complete.error_code != .NONE {
            return false;
        }

        break;
    }

    return true;
}
