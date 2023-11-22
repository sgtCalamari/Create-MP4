# Create-MP4

## Description

PowerShell function to automate conversion of DVD or disc-form video media into MP4 files for use with [Jellyfin](https://jellyfin.org/).

### High-Level Steps

1. Set up variables required and create staging directory
2. Execute [MakeMKV](https://www.makemkv.com/) to pull disc info
3. Create `.mkv` for largest title on disc (feature picture)
4. Eject disc and send SMS notification
5. Execute [HandBrake](https://handbrake.fr/) to convert `.mkv` to `.mp4`
6. Create archive and delete staging directory

## Dependencies

[MakeMKV](https://www.makemkv.com/download/) and [HandBrakeCLI](https://handbrake.fr/downloads2.php) are required for file extraction and conversion.

### MakeMKV

The `MakeMKVcon` argument specifying the path to `makemkvcon64.exe` is required for the Create-MP4 function. The default value is `C:\Program Files (x86)\MakeMKV\makemkvcon64.exe` or a different value can be provided at runtime.

Creates `.mkv` file from disc formatted media. This file is large as it is almost lossless but can be compressed into other file formats.

### HandBrakeCLI

The `HandBrakeCLI` argument specifying the path to `HandBrakeCLI.exe` is required for the Create-MP4 function. The default value is `C:\Program Files\HandBrakeCLI\HandBrakeCLI.exe` or a different value can be provided at runtime.

Compresses `.mkv` file into `.mp4` format for storage-friendliness.

## Usage Notes

Most parameters have default values that can be overwritten to suit your needs.

* `Title` : output file name, derived from disc information if not provided
* `diskReaderDrive` : the drive letter mapped in Windows for the disc reader
* `MakeMKVcon`: full file path to `makemkvcon64.exe`, described [above](#makemkv)
* `HandBrakeCLI` : full file path to `HandBrakeCLI.exe`, described [above](#handbrakecli)
* `ConfigFilePath` : file path to `.psd1` file with sensitive information used for SMS notifications *(not required)*
* `ProcessingPath` : script processing path, should have adequate permissions to create directory for staging MKV file
* `OutputDirectory` : directory to output processed `.mp4` file
* `ArchivePath` : path to write `.zip` file including conversion logs and disc information
