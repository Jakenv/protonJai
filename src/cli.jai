URL :: "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases";
LATEST_URL :: "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest";
DOWNLOAD_DIR :: "/tmp/protonjai";

Assets :: struct {
    name: string;
    browser_download_url: string;
}

Release :: struct {
    tag_name: string;
    assets: [] Assets;
}

Request :: struct {
    curl: *CURL;
    file: File;
}

print_yellow :: (format_string: string, args: .. Any) {
    write_string("\n\u001b[33m");
    print(format_string, .. args);
    write_string("\u001b[0m\n");
}

list_protons :: () {
    print_yellow("Available versions");
    {
        installed_protons := check_paths();
        response_body := request_info(URL);
        defer free(response_body);

        _, parsed_data := json_parse_string(response_body, [] Release);
        defer free(parsed_data.data);
        // I don't like this
        for *version, v_index: parsed_data {
            for *install, i_index: installed_protons {
                if contains(version.tag_name, install.*) {
                    version.tag_name = tprint("% (installed)", version.tag_name);
                    break;
                }
            }
        }
        for parsed_data {
            if it_index == 0 print("[%]:\t % (latest)\n", it_index+1, it.tag_name);
            else print("[%]:\t % \n", it_index+1, it.tag_name);
        }
    }
}

download_proton :: (proton_ver: int = 1) {
    print_yellow("Installing proton!");
    {
        installed_protons, steam_path := check_paths();
        response_body := request_info(URL);
        defer free(response_body);

        _, parsed_data := json_parse_string(response_body, [] Release);
        defer free(parsed_data.data);

        if proton_ver-1 >= parsed_data.count {
            print("There is no Proton under [%] check again with -list\n", proton_ver);
            return;
        }

        if array_find(installed_protons, parsed_data[proton_ver-1].tag_name) {
            print("Proton % already installed! Do you want to reinstall y/n?\n", parsed_data[proton_ver-1].tag_name);
            if !user_input() return;
        }

        download_data: struct {
            name: string;
            url: string;
        }

        for parsed_data[proton_ver-1].assets {
            if contains(it.name, "tar.gz") && contains(it.browser_download_url, "tar.gz") {
                download_data = .{
                    it.name,
                    it.browser_download_url,
                };
                break;
            }
        }
        filename := download(download_data.url, download_data.name);
        ok := extract_archive(filename, steam_path);
        if !ok {
            print("Extraction failed!");
        }
    }
}

user_input :: () -> bool {
    BUFFER_SIZE :: 1024;
    buffer: [BUFFER_SIZE] u8;
    input: string;
    input.data = buffer.data;

    reinstall: bool;

    while true {
        bytes_read := read(STDIN_FILENO, buffer.data + input.count, cast(u64) (buffer.count - input.count));
        if bytes_read < 0 {
            log_error("Couldn't read from stdin");
            exit(1);
        }
        if bytes_read {
            input.count += bytes_read;
            if begins_with(input, "y") || begins_with(input, "Y") {
                reinstall = true;
                break;
            } else {
                reinstall = false;
                break;
            }
        }
    }
    return reinstall;
}

// I have no idea how else I could modify visit_direcotires flag otherwise so copying the function it is lol
my_file_list :: (path: string, recursive := false, follow_directory_symlinks := true) -> [] string {
    files : [..] string;
    files.allocator = temp;

    visitor :: (info: *File_Visit_Info, user_data: *[..] string) {
        array_add(user_data, copy_string(info.full_name));
    }

    visit_files(path, recursive, *files, visitor, follow_directory_symlinks=follow_directory_symlinks, visit_directories=true);

    return files;
}

check_paths :: () -> [] string, string {
    steam_path := tprint("%/.steam/steam/compatibilitytools.d", join(get_home_directory(get_username())));
    assert(is_directory(steam_path) == true);

    installed_protons: [..] string;
    installed_protons.allocator = temp;

    paths_of_installed_protons := my_file_list(steam_path);

    for paths_of_installed_protons {
        _, _, right := split_from_right(it, #char "/");
        array_add(*installed_protons, right);
    }

    return installed_protons, steam_path;
}

write_string_callback :: (contents: *u8, count: u64, size: u64, text: *void) -> u64 #c_call {
    builder := cast(*String_Builder)text;

    push_context {
        append(builder, contents, xx size);
    }

    return size;
}

write_file_callback :: (contents: *u8, count: u64, size: u64, request: *Request) -> u64 #c_call {
    total_size := count * size;
    push_context {
        file_write(*request.file, contents, xx total_size);
        print_curl_stats(request.curl);
    }

    return total_size;
}

print_curl_stats :: (curl: *CURL) {
    total_time      : float64;
    download_speed  : float64;
    size_downloaded : float64;

    curl_easy_getinfo(curl, .TOTAL_TIME,     *total_time);
    curl_easy_getinfo(curl, .SPEED_DOWNLOAD, *download_speed);
    curl_easy_getinfo(curl, .SIZE_DOWNLOAD,  *size_downloaded);

    print("\rTime: %s, Speed: %MB/s, Downloaded: %MB",
          cast(int) total_time,
          cast(int)(download_speed / 1024.0 / 1024.0),
          cast(int)(size_downloaded / 1024.0 / 1024.0));
}

Setup_Curl :: (json: bool, url: string) -> *CURL, *curl_slist #expand {
    curl := curl_easy_init();
    assert(curl != null);
    `defer curl_easy_cleanup(curl);

    header: *curl_slist;
    header = curl_slist_append(header, "User-Agent: protonget");

    #if json {
        header = curl_slist_append(header, "Contnet-Type: application/json");
    }

    curl_easy_setopt(curl, .HTTPHEADER, header);
    curl_easy_setopt(curl, .FOLLOWLOCATION, 1);
    curl_easy_setopt(curl, .URL, temp_c_string(url));

    return curl, header;
}

request_info :: (url: string) -> string, int, CURLcode {
    curl, header := Setup_Curl(true, url);

    builder: String_Builder;
    defer free_buffers(*builder);
    curl_easy_setopt(curl, .WRITEFUNCTION, write_string_callback);
    curl_easy_setopt(curl, .WRITEDATA, *builder);

    curl_code := curl_easy_perform(curl);

    response_code: int;
    if curl_code == .OK  curl_easy_getinfo(curl, .RESPONSE_CODE, *response_code);
    response_body: string = builder_to_string(*builder);

    return response_body, response_code, curl_code;
}

download :: (url: string, target: string) -> string, int, CURLcode {
    curl, header := Setup_Curl(false, url);

    make_directory_if_it_does_not_exist(DOWNLOAD_DIR);
    set_working_directory(DOWNLOAD_DIR);

    out_file, ok := file_open(target, for_writing=true);
    if !ok {
        print("Failed to open the output file '%' for storing the download.\n", target);
        exit(1);
    }
    defer file_close(*out_file);

    request: Request;
    request.curl = curl;
    request.file = out_file;

    curl_easy_setopt(curl, .WRITEFUNCTION, write_file_callback);
    curl_easy_setopt(curl, .WRITEDATA, *request);
    print("Downloading %...\n", target);

    curl_code := curl_easy_perform(curl);

    response_code: int;
    if curl_code == .OK  curl_easy_getinfo(curl, .RESPONSE_CODE, *response_code);

    print_curl_stats(curl);
    print("\n");
    print("File % downloaded successfully!\n", target);

    return target, response_code, curl_code;
}

extract_archive :: (filename: string, extraction_path: string) -> bool {
    print("Extracting the file %\n", filename);
    set_working_directory(DOWNLOAD_DIR);

    a: *archive = archive_read_new();
    ext: *archive = archive_write_disk_new();
    entry: *archive_entry;

    spinner :: string.["|", "/", "-", "\\"];
    spin_idx: int = 0;

    defer {
        archive_read_close(a);
        archive_read_close(a);
        archive_write_close(ext);
        archive_write_free(ext);
    }

    extraction_path_for_c := join(extraction_path, "/");
    archive_read_support_format_tar(a);
    archive_read_support_filter_gzip(a);

    if archive_read_open_filename(a, temp_c_string(filename), 1024) != ARCHIVE_OK {
        log("Opening file failed\n");
        return false;
    }

    while archive_read_next_header(a, *entry) == ARCHIVE_OK {
        og_path := archive_entry_pathname(entry);

        final_path := join(extraction_path_for_c, to_string(og_path));
        archive_entry_set_pathname(entry, to_c_string(final_path));

        archive_write_header(ext, entry);
        buffer: *void;
        size: u64;
        offset: la_int64_t;

        print("\rExtracting... %", spinner[spin_idx]);
        spin_idx = (spin_idx + 1) % 4;
        while archive_read_data_block(a, *buffer, *size, *offset) == ARCHIVE_OK {
            archive_write_data_block(ext, buffer, size, offset);
        }
    }
    print("\n");
    print("Proton installed to %\n", extraction_path);

    return true;
}
