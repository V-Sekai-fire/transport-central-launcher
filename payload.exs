# Where every child in the payload comes from, per target.
#
# A tracked file rather than nine environment variables: a variable is invisible
# to the editor, absent from the project, and gone the next time somebody builds.
# Each entry pins a version and a digest, so a build either produces the payload
# this file describes or fails.
%{
  "windows_amd64" => [
    %{
      name: "versitygw.exe",
      version: "1.8.0",
      url:
        "https://github.com/versity/versitygw/releases/download/v1.8.0/versitygw_v1.8.0_Windows_x86_64.zip",
      extract: "versitygw_v1.8.0_Windows_x86_64/versitygw.exe",
      sha256: "from-release-asset"
    },
    %{
      name: "bao.exe",
      version: "2.6.2",
      url:
        "https://github.com/openbao/openbao/releases/download/v2.6.2/openbao_2.6.2_windows_amd64.zip",
      extract: "bao.exe",
      sha256: "from-release-asset"
    },
    %{
      name: "desync.exe",
      version: "1.1.3",
      url:
        "https://github.com/folbricht/desync/releases/download/v1.1.3/desync_1.1.3_windows_amd64.zip",
      extract: "desync.exe",
      sha256: "from-release-asset"
    },
    %{
      name: "fdbserver.exe",
      version: "7.3.79",
      url:
        "https://github.com/V-Sekai-fire/datasource-foundationdb/releases/download/7.3.79-weftspun-dev.2/fdbserver.windows.x86_64.exe",
      extract: "fdbserver.windows.x86_64.exe",
      sha256: "from-release-asset"
    },
    %{
      name: "libfdb_c.dll",
      version: "7.3.79",
      url:
        "https://github.com/V-Sekai-fire/datasource-foundationdb/releases/download/7.3.79-weftspun-dev.2/fdb_c.windows.x86_64.dll",
      extract: "fdb_c.windows.x86_64.dll",
      sha256: "from-release-asset"
    },
    %{
      name: "libgodot.dll",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/entities-godot",
      extract: "bin/libgodot.windows.template_release.x86_64.dll",
      sha256: "built-in-ci"
    },
    %{
      name: "iceoryx2_ffi_c.dll",
      version: "0.9.3",
      url: "https://github.com/V-Sekai-fire/interactor-elixir-libgodot",
      extract: "iceoryx2_ffi_c.dll",
      sha256: "built-in-ci"
    },
    %{
      name: "libgodot_host.exe",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/transport-elixir-libgodot-connector",
      extract: "samples/libgodot_host/host.cpp",
      sha256: "built-in-ci"
    }
  ],
  "linux_x86_64" => [
    %{
      name: "versitygw",
      version: "1.8.0",
      url:
        "https://github.com/versity/versitygw/releases/download/v1.8.0/versitygw_v1.8.0_Linux_x86_64.tar.gz",
      extract: "versitygw_v1.8.0_Linux_x86_64/versitygw",
      sha256: "from-release-asset"
    },
    %{
      name: "bao",
      version: "2.6.2",
      url:
        "https://github.com/openbao/openbao/releases/download/v2.6.2/openbao_2.6.2_linux_amd64.tar.gz",
      extract: "bao",
      sha256: "from-release-asset"
    },
    %{
      name: "fdbserver",
      version: "7.3.79",
      url: "https://github.com/apple/foundationdb/releases/download/7.3.79/fdbserver.x86_64",
      extract: "fdbserver.x86_64",
      sha256: "from-release-asset"
    },
    %{
      name: "libfdb_c",
      version: "7.3.79",
      url: "https://github.com/apple/foundationdb/releases/download/7.3.79/libfdb_c.x86_64.so",
      extract: "libfdb_c.x86_64.so",
      sha256: "from-release-asset"
    },
    %{
      name: "libgodot",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/entities-godot",
      extract: "bin/libgodot.linuxbsd.template_release.x86_64.so",
      sha256: "built-locally"
    },
    %{
      name: "libiceoryx2_ffi_c.so",
      version: "0.9.3",
      url: "https://github.com/V-Sekai-fire/interactor-elixir-libgodot",
      extract: "libiceoryx2_ffi_c.so",
      sha256: "built-locally"
    },
    %{
      name: "libgodot_host",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/transport-elixir-libgodot-connector",
      extract: "samples/libgodot_host/host.cpp",
      sha256: "built-locally"
    },
    %{
      name: "desync",
      version: "1.1.3",
      url:
        "https://github.com/folbricht/desync/releases/download/v1.1.3/desync_1.1.3_linux_amd64.tar.gz",
      extract: "desync",
      sha256: "from-release-asset"
    }
  ],
  "linux_arm64" => [
    %{
      name: "versitygw",
      version: "1.8.0",
      url:
        "https://github.com/versity/versitygw/releases/download/v1.8.0/versitygw_v1.8.0_Linux_arm64.tar.gz",
      extract: "versitygw_v1.8.0_Linux_arm64/versitygw",
      sha256: "from-release-asset"
    },
    %{
      name: "bao",
      version: "2.6.2",
      url:
        "https://github.com/openbao/openbao/releases/download/v2.6.2/openbao_2.6.2_linux_arm64.tar.gz",
      extract: "bao",
      sha256: "from-release-asset"
    },
    %{
      name: "fdbserver",
      version: "7.3.79",
      url: "https://github.com/apple/foundationdb/releases/download/7.3.79/fdbserver.aarch64",
      extract: "fdbserver.aarch64",
      sha256: "from-release-asset"
    },
    %{
      name: "libfdb_c",
      version: "7.3.79",
      url: "https://github.com/apple/foundationdb/releases/download/7.3.79/libfdb_c.aarch64.so",
      extract: "libfdb_c.aarch64.so",
      sha256: "from-release-asset"
    },
    %{
      name: "libgodot",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/entities-godot",
      extract: "bin/libgodot.linuxbsd.template_release.arm64.so",
      sha256: "built-locally"
    },
    %{
      name: "libiceoryx2_ffi_c.so",
      version: "0.9.3",
      url: "https://github.com/V-Sekai-fire/interactor-elixir-libgodot",
      extract: "libiceoryx2_ffi_c.so",
      sha256: "built-locally"
    },
    %{
      name: "libgodot_host",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/transport-elixir-libgodot-connector",
      extract: "samples/libgodot_host/host.cpp",
      sha256: "built-locally"
    },
    %{
      name: "desync",
      version: "1.1.3",
      url:
        "https://github.com/folbricht/desync/releases/download/v1.1.3/desync_1.1.3_linux_arm64.tar.gz",
      extract: "desync",
      sha256: "from-release-asset"
    }
  ],
  "macos_arm64" => [
    %{
      name: "versitygw",
      version: "1.8.0",
      url:
        "https://github.com/versity/versitygw/releases/download/v1.8.0/versitygw_v1.8.0_Darwin_arm64.tar.gz",
      extract: "versitygw_v1.8.0_Darwin_arm64/versitygw",
      sha256: "bd25227820ba19d5"
    },
    %{
      name: "bao",
      version: "2.6.2",
      url:
        "https://github.com/openbao/openbao/releases/download/v2.6.2/openbao_2.6.2_darwin_arm64.tar.gz",
      extract: "bao",
      sha256: "d476d17e81a35e6d"
    },
    %{
      name: "fdbserver",
      version: "7.3.79",
      url:
        "https://github.com/apple/foundationdb/releases/download/7.3.79/FoundationDB-7.3.79_arm64.pkg",
      extract: "FoundationDB-server.pkg/Payload/usr/local/libexec/fdbserver",
      sha256: "67f6c43eecf3da67"
    },
    %{
      name: "libfdb_c",
      version: "7.3.79",
      url:
        "https://github.com/apple/foundationdb/releases/download/7.3.79/FoundationDB-7.3.79_arm64.pkg",
      extract: "FoundationDB-clients.pkg/Payload/usr/local/lib/libfdb_c.dylib",
      sha256: "dee08032dd3a7aac"
    },
    %{
      name: "libgodot",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/entities-godot",
      extract: "bin/libgodot.macos.template_release.arm64.dylib",
      sha256: "built-in-ci"
    },
    %{
      name: "libiceoryx2_ffi_c.dylib",
      version: "0.4.1",
      url: "https://github.com/V-Sekai-fire/interactor-elixir-libgodot",
      extract: "lib_godot_connector-nif-2.17-aarch64-apple-darwin-4.5.1-5.tar.gz",
      sha256: "from-release-asset"
    },
    %{
      name: "libgodot_host",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/transport-elixir-libgodot-connector",
      extract: "samples/libgodot_host/host.cpp",
      sha256: "built-locally-against-4.8-api"
    },
    %{
      name: "desync",
      version: "1.1.3",
      url:
        "https://github.com/folbricht/desync/releases/download/v1.1.3/desync_1.1.3_darwin_arm64.tar.gz",
      extract: "desync",
      sha256: "ef066048a903d3fc"
    }
  ]
}
