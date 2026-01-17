# Visual Studio Dark+ Colors
colors=(
  "#1E1E1E"
  "#DCDCDC"
  "#FFFFFF"
  "#0F0F0F"
  "#264F78"
  "#608B4E"
  "#9CDCFE"
  "#C586C0"
  "#B5CEA8"
  "#569CD6"
  "#D69D85"
  "#E3BBAB"
  "#9B9B9B"
  "#DCDCAA"
  "#4EC9B0"
  "#70727E"
  "#687687"
  "#ff3333"
  "#282828"
  "#68685B"
  "#808080"
  "#92CAF4"
  "#C8C8C8"
  "#D7BA7D"
  "#87CEFA"
  "#F92672"
  "#A6E22E"
  "#967EFB"
  "#565656"
  "#272852"
  "#275822"
  "#A72822"
)

# Loop through each color and display it
for color in "${colors[@]}"; do
  # Convert the hex color to RGB for ANSI escape code
  r=$((16#${color[2, 3]}))
  g=$((16#${color[4, 5]}))
  b=$((16#${color[6, 7]}))

  # Display the color with the color code as text
  printf "\e[48;2;%d;%d;%dm %-10s \e[0m\n" $r $g $b $color
done
