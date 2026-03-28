for file in ./*.typ; do
    name="${file%.typ}"
    echo "Compiling $file..."
    typst compile --root ../ "$file" "${name}.svg" --ignore-system-fonts
    echo "Rendered ${name}.svg"
done
