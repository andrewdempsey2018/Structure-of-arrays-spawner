import csv

with open("input.csv", newline="") as infile:
    reader = csv.DictReader(infile)

    columns = {name: [] for name in reader.fieldnames}

    for row in reader:
        for name in reader.fieldnames:
            value = row[name].strip()

            if value == "":
                continue

            columns[name].append(f"${int(value):02X}")

with open("output.txt", "w") as outfile:
    for name, values in columns.items():
        outfile.write(name + ":\n")

        for i in range(0, len(values), 16):
            outfile.write(
                "  .byte " +
                ",".join(values[i:i + 16]) +
                "\n"
            )

        outfile.write("\n")

print("Done!")