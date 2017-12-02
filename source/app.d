// github.com/dmi7ry/alpha-bleeding-d

import std.stdio, std.conv, std.getopt, std.file, std.algorithm.mutation, std.path, std.algorithm, std.range;
import dlib.image, dlib.image.image;

void main(string[] args)
{
	bool replace;
	bool removeAlpha;

	auto exeName = args[0];

	// Check arguments
	GetoptResult helpInformation;
	try
	{
		helpInformation = getopt(args,
			"replace|r", "Overwrite original file", &replace,
			"noalpha|n", "Store an extra image with removed alpha", &removeAlpha);
	}
	catch (Throwable)
	{
		writeln("Wrong arguments!\n");
		printHelp(helpInformation, exeName);
		return;
	}

	if (helpInformation.helpWanted || args.length == 1)
	{
		printHelp(helpInformation, exeName);
		return;
	}

	bool wrongArgs;

	// A directory was specified
	if (args.length > 1 && args[1].exists && args[1].isDir)
	{
		immutable auto directorySource = args[1];
		string directoryDestination;

		// Use the specified name
		if (args.length == 3)
			directoryDestination = args[2];
		// Replace old file
		else if (!replace)
		{
			directoryDestination = directorySource ~ "-result";
			if (directoryDestination.exists && !dirEntries(directoryDestination, SpanMode.shallow).empty)
			{
				directoryDestination ~= "1";

				uint counter = 2;
				while (directoryDestination.exists && !dirEntries(directoryDestination, SpanMode.shallow).empty)
				{
					directoryDestination = directoryDestination[0..$-1] ~ to!string(counter++);
				}
			}

			if (!exists(directoryDestination))
				mkdir(directoryDestination);

			writeln("target dir: ", directoryDestination);
		}

		foreach (string name; dirEntries(directorySource, "*.png", SpanMode.breadth).filter!(a => a.isFile))
		{
			if (replace)
				processFile(name, name, removeAlpha);
			else
				processFile(name, directoryDestination ~ "\\" ~ baseName(name), removeAlpha);

		}
	}
	// A file was specified
	else if (args.length > 1 && args[1].exists && !args[1].isDir)
	{
		// Replace old file
		if (replace)
		{
			processFile(args[1], args[1], removeAlpha);
		}
		// Use the specified name
		else if (args.length == 3)
		{
			processFile(args[1], args[2], removeAlpha);
		}
		// Generate name
		else
		{
			auto newName = stripExtension(args[1]) ~ "-result";
			auto counter = 1;
			if (exists(newName ~ ".png"))
			{
				while (exists(newName ~ to!string(counter++) ~ ".png"))
				{
				}

				newName ~= to!string(counter - 1);
			}

			processFile(args[1], newName ~ ".png", removeAlpha);
		}
	}
	else
	{
		wrongArgs = true;
	}

	if (wrongArgs)
	{
		printHelp(helpInformation, exeName);
		return;
	}

	writeln("START");
}

private void printHelp(ref GetoptResult helpInformation, string filename)
{
	defaultGetoptPrinter("github.com/dmi7ry/alpha-bleeding-d", helpInformation.options);
	writeln("\nExamples of use:\n",
	filename, " -replace -noalpha file.png\n",
	filename, " -replace directory\n",
	filename, " file.png\n",
	filename, " file.png result.png\n");
}

private void processFile(string sourceFile, string destinationFile, bool removeAlpha)
{
	if (!exists(sourceFile))
	{
		writeln("[error] File not found: ", sourceFile);
		return;
	}

    SuperImage img;
	
	try
	{
		img = loadPNG(sourceFile);
	}
	catch (Throwable)
	{
		writeln("[error] Can't open image: ", sourceFile);
		return;
	}

    writeln("File: ", sourceFile, ", Width: ", img.width, ", Height: ", img.height);
    writeln("src: ", sourceFile, ", dest: ", destinationFile);
    
    auto data = img.data();
    alphaBleeding(data, img.width, img.height);

    img.savePNG(destinationFile);

	if (removeAlpha)
	{
		for (int j; j<img.height; ++j)
		{
			for (int i; i<img.width;++i)
			{
				auto col = img[i, j];
				col[3] = 1.0;
				img[i, j] = col;
			}
		}
	
	    img.savePNG(stripExtension(destinationFile) ~ "-no_alpha.png");
	}
}

private void alphaBleeding(ubyte[] data, int width, int height)
{
    const uint N = width * height;
    auto opaque = new byte[N];
    auto loose = new bool[N];
    uint[] pending;
    uint[] pendingNext;

	int[2][8] offsets = [
		[-1, -1], [ 0, -1], [ 1, -1],
		[-1,  0],           [ 1,  0],
		[-1,  1], [ 0,  1], [ 1,  1]
	];
    
	for (uint i, j = 3; i < N; i++, j += 4)
	{
		if (data[j] == 0)
		{
			auto isLoose = true;

			immutable int x = i % width;
			immutable int y = i / width;

			for (int k; k < 8; k++)
			{
				immutable int s = offsets[k][0];
				immutable int t = offsets[k][1];

				if (x + s >= 0 && x + s < width && y + t >= 0 && y + t < height)
				{
					immutable uint index = j + 4 * (s + t * width);

					if (data[index] != 0)
					{
						isLoose = false;
						break;
					}
				}
			}

			if (!isLoose)
				pending ~= i;
			else
				loose[i] = true;
		}
		else
		{
			opaque[i] = -1;
		}
	}

    while (pending.length > 0)
	{
		pendingNext.length = 0;

		for (uint p; p < pending.length; p++)
		{
			uint i = pending[p] * 4;
			uint j = pending[p];

			immutable int x = j % width;
			immutable int y = j / width;

			int r, g, b;
			int count;

			for (uint k; k < 8; k++)
			{
				int s = offsets[k][0];
				int t = offsets[k][1];

				if (x + s >= 0 && x + s < width && y + t >= 0 && y + t < height)
				{
					t *= width;

					if (opaque[j + s + t] & 1)
					{
						immutable uint index = i + 4 * (s + t);

						r += data[index + 0];
						g += data[index + 1];
						b += data[index + 2];

						count++;
					}
				}
			}

			if (count > 0)
			{
				data[i + 0] = to!ubyte(r / count);
				data[i + 1] = to!ubyte(g / count);
				data[i + 2] = to!ubyte(b / count);

				opaque[j] = to!ubyte(0xFE);

				for (uint k; k < 8; k++)
				{
					immutable int s = offsets[k][0];
					immutable int t = offsets[k][1];

					if (x + s >= 0 && x + s < width && y + t >= 0 && y + t < height)
					{
						uint index = j + s + t * width;

						if (loose[index])
						{
							pendingNext ~= index;
							loose[index] = false;
						}
					}
				}
			}
			else
			{
				pendingNext ~= j;
			}
		}

		if (pendingNext.length > 0)
		{
			for (uint p; p < pending.length; p++)
				opaque[pending[p]] >>= 1;
		}

        pending.swap(pendingNext);
	}
}
