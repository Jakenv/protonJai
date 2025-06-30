#import "Curl";
#import "Basic";
#import "File";
// #import "Command_Line";

URL :: "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-4/GE-Proton10-4.tar.gz";

HELP :: #string DONE
    print("-h/-help for how to use\n");
    return;
DONE

main :: () {
    args := get_command_line_arguments();
    defer array_reset(*args);

    do_curl := false;
    target := "proton.tar.gz";

    if args.count == 1 {
        #insert HELP;
    }

    for args if args.count > 1 {
        if it == {
            case "-p"; #through;
            case "-proton";
                do_curl = true;
                break;
            case "-h"; #through;
            case "-help";
                print("-p/-proton to download archive\n");
                return;
            case;
                HELP;
        }
    }


    if(do_curl) {
        download(URL, target);
    }
}

write_callback :: (contents: *u8, count: u64, size: u64, file: *File) -> u64 #c_call {
    total_size := count * size;
    push_context {
        file_write(file, contents, cast(s64) total_size);
        print_curl_stats();
    }

    return total_size;
}


print_curl_stats :: () {
    total_time      : float64;
    download_speed  : float64;
    size_downloaded : float64;

    curl_easy_getinfo(handle, .TOTAL_TIME,     *total_time);
    curl_easy_getinfo(handle, .SPEED_DOWNLOAD, *download_speed);
    curl_easy_getinfo(handle, .SIZE_DOWNLOAD,  *size_downloaded);

    print("Time: %s, Speed: %MB/s, Downloaded: %MB\n", total_time, download_speed / 1024.0 / 1024.0, size_downloaded / 1024.0 / 1024.0);
}

download :: (url: string, target: string) -> bool {
    handle = curl_easy_init();
    assert(handle != null);
    defer curl_easy_cleanup(handle);

    chunk: *curl_slist;
    chunk = curl_slist_append(chunk, "USer-Agent: protonget");
    curl_easy_setopt(handle, .HTTPHEADER, chunk);
    curl_easy_setopt(handle, .FOLLOWLOCATION, 1);
    curl_easy_setopt(handle, .URL, temp_c_string(url));

    out_file, ok := file_open(target, for_writing=true);
    if !ok {
        print("Failed to open the output file '%' for storing the download.\n", target);
        return false;
    }
    defer file_close(*out_file);
    curl_easy_setopt(handle, .WRITEFUNCTION, write_callback);
    curl_easy_setopt(handle, .WRITEDATA, *out_file);

    print("Downloading %...\n", target);

    res := curl_easy_perform(handle);
    if res != .OK {
        error_message := to_string(curl_easy_strerror(res));
        defer free(error_message);
        print("Curl Error: %\n", error_message);
        return false;
    }
    print_curl_stats();
    print("File % downloaded successfully!\n", target);
    return true;
}

handle: *CURL;
