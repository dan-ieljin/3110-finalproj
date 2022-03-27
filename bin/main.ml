open Twitter
open Posts
open Command

let print_blue s =
  ANSITerminal.print_string [ ANSITerminal.cyan ] (s ^ "\n")

let print_red s =
  ANSITerminal.print_string [ ANSITerminal.red ] (s ^ "\n")

let rec post () =
  let p = read_line () in
  try
    add_post p |> to_json;
    print_blue "\nPost successful!\n";
    get_command ()
  with
  | InvalidPost "Too long" ->
      print_red "\nYour post exceeds the character limit.\n";
      print_blue "Please enter a new post:\n";
      post ()
  | InvalidPost "Too short" ->
      print_red "\nYour post contains no characters.\n";
      print_blue "Please enter a new post:\n";
      post ()
  | InvalidPost "hashtag" ->
      print_red "\nYour post contains too many hashtags.\n";
      print_blue "Please enter a new post:\n";
      post ()

and get_command () =
  let posts = Yojson.Basic.from_file "data/posts.json" in
  print_blue
    "\nWhat would you like to do? Commands: post, homepage, quit.\n";
  try
    match parse (read_line ()) with
    | Post ->
        print_blue "\nEnter a post:\n";
        post ()
    | HomePage ->
        print_blue "\nMain Feed:\n";
        Yojson.Basic.pretty_print Format.std_formatter posts;
        print_blue "\nWhat would you like to do?\n";
        get_command ()
    | Delete _ -> failwith "Unimplemented"
    | Like i -> begin
        try
          posts |> from_json |> like_post i |> to_json;
          print_blue ("\nPost" ^ string_of_int i ^ "liked.\n");
          get_command ()
        with PostNotFound ->
          print_red
            "\nNo such post exists. Please enter a new command.\n";
          get_command ()
      end
    | Quit ->
        print_blue "See you next time!\n";
        exit 0
  with Invalid | Empty ->
    print_red "\nInvalid command. Please enter a new command.\n";
    get_command ()

let main () =
  print_blue "\nWelcome to Twitter.\n";
  get_command

let () = main () ()