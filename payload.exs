# Where every child in the payload comes from, per target.
#
# A tracked file rather than nine environment variables: a variable is invisible
# to the editor, absent from the project, and gone the next time somebody builds.
# Each entry pins a version and a digest, so a build either produces the payload
# this file describes or fails.
%{
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
      version: "7.3.76",
      url: "https://github.com/apple/foundationdb/releases/download/7.3.76/fdbserver.aarch64",
      extract: "fdbserver.aarch64",
      sha256: "from-release-asset"
    },
    %{
      name: "libfdb_c",
      version: "7.3.76",
      url: "https://github.com/apple/foundationdb/releases/download/7.3.76/libfdb_c.aarch64.so",
      extract: "libfdb_c.aarch64.so",
      sha256: "from-release-asset"
    },
    %{
      name: "libgodot",
      version: "4.8.dev.bc391afc4",
      url: "https://github.com/V-Sekai-fire/entities-libgodot",
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
      version: "0.9.6",
      url:
        "https://github.com/folbricht/desync/releases/download/v0.9.6/desync_0.9.6_linux_arm64.tar.gz",
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
      version: "7.3.76",
      url:
        "https://github.com/apple/foundationdb/releases/download/7.3.76/FoundationDB-7.3.76_arm64.pkg",
      extract: "usr/local/libexec/fdbserver",
      sha256: "67f6c43eecf3da67"
    },
    %{
      name: "libfdb_c",
      version: "7.3.76",
      url:
        "https://github.com/apple/foundationdb/releases/download/7.3.76/FoundationDB-7.3.76_arm64.pkg",
      extract: "usr/local/lib/libfdb_c.dylib",
      sha256: "dee08032dd3a7aac"
    },
    %{
      name: "libgodot",
      version: "4.5.1-5",
      url:
        "https://github.com/V-Sekai-fire/interactor-elixir-libgodot/releases/download/draft-7bc02d4e685a965ccdd4587ba82e518694befc74/lib_godot_connector-nif-2.17-aarch64-apple-darwin-4.5.1-5.tar.gz",
      extract: "libgodot.dylib",
      sha256: "0c3f2a1e00000000"
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
      version: "1.1.4",
      url: "https://github.com/folbricht/desync",
      extract: "desync",
      sha256: "ef066048a903d3fc"
    }
  ]
}
