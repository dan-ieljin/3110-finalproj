open Yojson.Basic.Util

type post = {
  text : string;
  hashtags : string list;
  timestamp : string;
  id : int;
  username : string;
  likes : int;
  retweets : int;
}

type t = post list

exception InvalidPost of string
exception PostNotFound

let get_date (tm : Unix.tm) =
  let month = string_of_int tm.tm_mon in
  let day = string_of_int tm.tm_mday in
  let year = string_of_int (1900 + tm.tm_year) in
  month ^ "/" ^ day ^ "/" ^ year

let get_time (tm : Unix.tm) =
  let hour =
    if tm.tm_hour > 12 then string_of_int (tm.tm_hour mod 12)
    else string_of_int tm.tm_hour
  in
  let minute =
    if tm.tm_min < 10 then "0" ^ string_of_int tm.tm_min
    else string_of_int tm.tm_min
  in
  let ending = if tm.tm_hour < 12 then "AM" else "PM" in
  hour ^ ":" ^ minute ^ " " ^ ending

let date_and_time tm = get_time tm ^ " " ^ get_date tm

(**[parse_record j] helps parse the post text, hashtags, and timestamp.*)
let parse_record j =
  {
    text = j |> member "tweet" |> to_string;
    hashtags = j |> member "hashtags" |> to_list |> List.map to_string;
    timestamp = j |> member "timestamp" |> to_string;
    id = j |> member "id" |> to_int;
    username = j |> member "username" |> to_string;
    likes = j |> member "likes" |> to_int;
    retweets = j |> member "retweets" |> to_int;
  }

let from_json json : t =
  try json |> member "posts" |> to_list |> List.map parse_record
  with Type_error (s, _) -> failwith ("Parsing error: " ^ s)

let hashtags s =
  let text_list =
    s |> String.lowercase_ascii |> String.split_on_char ' '
  in
  List.filter (fun x -> x.[0] = '#') text_list

let create_post s id_val user =
  {
    text = s;
    hashtags =
      (if List.length (hashtags s) <= 5 then hashtags s
      else raise (InvalidPost "hashtag"));
    timestamp = date_and_time (Unix.localtime (Unix.time ()));
    id = id_val;
    username = user;
    likes = 0;
    retweets = 0;
  }

let last_id (post_list : t) =
  if List.length post_list = 0 then 0
  else (List.nth post_list (List.length post_list - 1)).id

let add_post s user : t =
  let length = s |> String.trim |> String.length in
  if length > 280 then raise (InvalidPost "Too long")
  else if length <= 0 then raise (InvalidPost "Too short");

  let post_list =
    Yojson.Basic.from_file "data/posts.json" |> from_json
  in
  try post_list @ [ create_post s (last_id post_list + 1) user ]
  with InvalidPost "hashtag" -> raise (InvalidPost "hashtag")

let rec delete_post id posts : t =
  let decr_ids post_lst =
    match post_lst with
    | [] -> []
    | h :: t -> List.map (fun x -> { x with id = x.id - 1 }) (h :: t)
  in
  match posts with
  | [] -> raise PostNotFound
  | h :: t -> if h.id = id then decr_ids t else h :: delete_post id t

let rec like_post_helper i post_lst post_lst_return =
  match post_lst with
  | [] -> post_lst_return
  | {
      text = x;
      hashtags = x2;
      timestamp = x3;
      id = idnum;
      username = x4;
      likes = l;
      retweets = x5;
    }
    :: t ->
      let h =
        {
          text = x;
          hashtags = x2;
          timestamp = x3;
          id = idnum;
          username = x4;
          likes = l;
          retweets = x5;
        }
      in
      if idnum = i then
        like_post_helper i t
          ({ h with likes = l + 1 } :: post_lst_return)
      else like_post_helper i t (h :: post_lst_return)

let like_post i post_lst =
  if last_id post_lst < i || i < 1 then raise PostNotFound
  else List.rev (like_post_helper i post_lst [])

(** [to_yojson p] converts a the data of a post [p] displayed in a
    record into a Yojson type association list. *)
let to_yojson p : Yojson.Basic.t =
  `Assoc
    [
      ("tweet", `String p.text);
      ("hashtags", `List (List.map (fun x -> `String x) p.hashtags));
      ("timestamp", `String p.timestamp);
      ("id", `Int p.id);
      ("username", `String p.username);
      ("likes", `Int p.likes);
      ("retweets", `Int p.retweets);
    ]

(** File containing the JSON represenation of post list. *)
let file = "data/posts.json"

let to_json post_list =
  let json_output (post_list : t) : Yojson.Basic.t =
    `Assoc [ ("posts", `List (List.map to_yojson post_list)) ]
  in
  let yojson_post = json_output post_list in
  let oc = open_out file in
  Yojson.Basic.to_channel oc yojson_post;
  close_out oc

let pp_posts (lst : post list) =
  let pp_elt (post : post) =
    "Post [" ^ string_of_int post.id ^ "] by " ^ post.username ^ " at "
    ^ post.timestamp ^ "\n" ^ post.text ^ "\n\n"
  in
  let pp_elts lst =
    let rec loop n acc = function
      | [] -> acc
      | [ h ] -> acc ^ pp_elt h
      | h1 :: (_ :: _ as t') ->
          if n = 100 then acc ^ "..." (* stop printing long list *)
          else loop (n + 1) (acc ^ pp_elt h1) t'
    in
    loop 0 "" lst
  in
  pp_elts lst

let is_substr str sub =
  let reg = Str.regexp_string sub in
  try
    ignore (Str.search_forward reg str 0);
    true
  with Not_found -> false

let rec search_posts (key : string) (lst : post list) =
  match lst with
  | [] -> []
  | post :: t ->
      if is_substr post.text key then post :: search_posts key t
      else search_posts key t

let user_posts (user : string) (lst : post list) =
  List.filter (fun post -> post.username = user) lst
