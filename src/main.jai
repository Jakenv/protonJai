URL :: "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases";
My_Argument_Flags :: Argument_Flags.FREE_ARGUMENTS_ALLOWED|.SORT_HELP|.ALIGN_HELP|.SHOW_HELP_ON_ERROR;
Arguments :: struct {
    list: bool; @"?List available versions"
    proton: bool; @"?If present it will download latest version"
}

print_yellow :: (format_string: string, args: .. Any) {
    write_string("\n\u001b[33m");
    print(format_string, .. args);
    write_string("\u001b[0m\n");
}

main :: () {
    ok, args, is_set := parse_arguments(Arguments, flags=My_Argument_Flags);

    if !ok {
        return;
    }

    target := "proton.tar.gz";
    header: *curl_slist;
    header = curl_slist_append(header, "User-Agent: protonget");

    if args.list {
        print_yellow("Getting list of versions");
        {
            response, code, ok := request(header, URL);
            defer free(response);
            print("response body preview:\n%\n", response);
            print("Response code: %\n", code);
        }
        return;
    }
    if args.proton {
        download(header, URL, target);
        return;
    }

    print("-help for list of commands\n"); return;
}

write_string_callback :: (contents: *u8, count: u64, size: u64, text: *void) -> u64 #c_call {
    builder := cast(*String_Builder)text;

    push_context {
        append(builder, contents, xx size);
    }

    return size;
}

write_file_callback :: (contents: *u8, count: u64, size: u64, file: *File) -> u64 #c_call {
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

    print("Time: %s, Speed: %MB/s, Downloaded: %MB\n",
          cast(int) total_time,
          cast(int)(download_speed / 1024.0 / 1024.0),
          cast(int)(size_downloaded / 1024.0 / 1024.0));

}

request :: (header: *curl_slist, url: string) -> response_body: string, response_code: int, curl_code: CURLcode {
    handle = curl_easy_init();
    assert(handle != null);
    defer curl_easy_cleanup(handle);
    header = curl_slist_append(header, "Contnet-Type: application/json");

    curl_easy_setopt(handle, .HTTPHEADER, header);
    curl_easy_setopt(handle, .FOLLOWLOCATION, 1);
    curl_easy_setopt(handle, .URL, temp_c_string(url));

    builder: String_Builder;
    defer free_buffers(*builder);
    curl_easy_setopt(handle, .WRITEFUNCTION, write_string_callback);
    curl_easy_setopt(handle, .WRITEDATA, *builder);

    curl_code := curl_easy_perform(handle);

    response_code: int;
    if curl_code == .OK  curl_easy_getinfo(handle, .RESPONSE_CODE, *response_code);
    response_body: string = builder_to_string(*builder);

    return response_body, response_code, curl_code;
}

download :: (header: curl_slist, url: string, target: string) -> bool {
    handle = curl_easy_init();
    assert(handle != null);
    defer curl_easy_cleanup(handle);

    curl_easy_setopt(handle, .HTTPHEADER, header);
    curl_easy_setopt(handle, .FOLLOWLOCATION, 1);
    curl_easy_setopt(handle, .URL, temp_c_string(url));

    out_file, ok := file_open(target, for_writing=true);
    if !ok {
        print("Failed to open the output file '%' for storing the download.\n", target);
        return false;
    }
    defer file_close(*out_file);
    curl_easy_setopt(handle, .WRITEFUNCTION, write_file_callback);
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

#import "Curl";
#import "jaison";
#import "Basic";
#import "String";
#import "File";
#import "Command_Line";
