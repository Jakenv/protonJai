#load "cli.jai";

My_Argument_Flags :: Argument_Flags.FREE_ARGUMENTS_ALLOWED|.SORT_HELP|.ALIGN_HELP|.SHOW_HELP_ON_ERROR;

Arguments :: struct {
    list:   bool; @"?List available versions"
    proton: u32;  @"?Download selected version of proton -list to see available options then '-proton <number>'"
    latest: bool; @"?Just download and install latest version"
}

main :: () {
    ok, args, is_set := parse_arguments(Arguments, flags=My_Argument_Flags);

    if !ok {
        return;
    }

    if args.list {
        list_protons();
        return;
    }

    if args.proton {
        download_proton(args.proton);
        return;
    }

    if args.latest {
        download_proton();
        return;
    }
}

#import "Basic";
#import "Command_Line";
#import "Curl";
#import "File";
#import "File_Utilities";
#import "jaison";
#import "jai-libarchive";
#import "String";
#import "System";
#import "POSIX";
