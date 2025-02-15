$gtk.disable_controller_config!

# Logical canvas width and height
WIDTH = 1280
HEIGHT = 720

# Nokia screen dimensions
VIRTUAL_WIDTH = 84
VIRTUAL_HEIGHT = 48

# Determine best fit zoom level
ZOOM_WIDTH = (WIDTH / VIRTUAL_WIDTH).floor
ZOOM_HEIGHT = (HEIGHT / VIRTUAL_HEIGHT).floor
ZOOM = [ZOOM_WIDTH, ZOOM_HEIGHT].min

# Compute the offset to center the Nokia screen
OFFSET_X = (WIDTH - VIRTUAL_WIDTH * ZOOM) / 2
OFFSET_Y = (HEIGHT - VIRTUAL_HEIGHT * ZOOM) / 2

# Compute the scaled dimensions of the Nokia screen
ZOOMED_WIDTH = VIRTUAL_WIDTH * ZOOM
ZOOMED_HEIGHT = VIRTUAL_HEIGHT * ZOOM

def tick(args)
  init_game(args) if args.state.tick_count.zero?

  handle_input(args)
  update_game(args)
  render_game(args)
end

def init_game(args)
  args.state.player ||= {
    x: VIRTUAL_WIDTH / 2,
    y: VIRTUAL_HEIGHT / 2,
    w: 1,
    h: 1,
    speed: 1,
    color: [255, 255, 255]
  }
  
  args.state.current_room ||= generate_room(args)
  args.state.score ||= 0
end

def handle_input(args)
  if args.inputs.keyboard.key_held.left
    args.state.player.x -= args.state.player.speed
  elsif args.inputs.keyboard.key_held.right
    args.state.player.x += args.state.player.speed
  end
  
  if args.inputs.keyboard.key_held.up
    args.state.player.y += args.state.player.speed
  elsif args.inputs.keyboard.key_held.down
    args.state.player.y -= args.state.player.speed
  end
end

def update_game(args)
  args.state.player.x = args.state.player.x.clamp(0, VIRTUAL_WIDTH - args.state.player.w)
  args.state.player.y = args.state.player.y.clamp(0, VIRTUAL_HEIGHT - args.state.player.h)
  
  if player_at_exit?(args)
    handle_room_exit(args)
  end
end

def render_game(args)
  args.outputs.background_color = [0, 0, 0]
  args.outputs[:scene].w = VIRTUAL_WIDTH
  args.outputs[:scene].h = VIRTUAL_HEIGHT
  args.outputs[:scene].background_color = [199, 240, 216]
  
  render_room(args)
  
  args.outputs[:scene].solids << [
    args.state.player.x,
    args.state.player.y,
    args.state.player.w,
    args.state.player.h,
    *args.state.player.color
  ]
  
  args.outputs.labels << [
    10, 700, "Score: #{args.state.score}",
    255, 255, 255
  ]

  args.outputs.sprites << {
    x: WIDTH / 2,
    y: HEIGHT / 2,
    w: ZOOMED_WIDTH,
    h: ZOOMED_HEIGHT,
    anchor_x: 0.5,
    anchor_y: 0.5,
    path: :scene
  }
end

def generate_room(args)
  h = 8
  w = 4
  safe_path = {
    output: { x: VIRTUAL_WIDTH - w, y: (VIRTUAL_HEIGHT / 2) - (h / 2), w: w, h: h, r: 0, g: 255, b: 0 },
    reward: 10,
  }
  
  dangerous_path = {
    output: { x: 0, y: (VIRTUAL_HEIGHT / 2) - (h / 2), w: w, h: h, r: 255, g: 0, b: 0 },
    reward: 30,
  }
  
  {
    safe_path: safe_path,
    dangerous_path: dangerous_path
  }
end

def render_room(args)
  room = args.state.current_room
  
  args.outputs[:scene].solids << room.safe_path.output
  args.outputs[:scene].solids << room.dangerous_path.output

end

def player_at_exit?(args)
  player = args.state.player
  room = args.state.current_room
  
  
  [room.safe_path, room.dangerous_path].any? do |path|
    args.geometry.intersect_rect?(player, path.output)
  end
end

def handle_room_exit(args)
  player = args.state.player
  room = args.state.current_room
  
  player_rect = [player.x, player.y, player.w, player.h]
  
  if args.geometry.intersect_rect?(
    player_rect,
    [room.safe_path.output.x, room.safe_path.output.y, room.safe_path.output.w, room.safe_path.output.h]
  )
    args.state.score += room.safe_path.reward
  else
    if rand < 0.5
      args.state.score += room.dangerous_path.reward
    else
      args.state.score = [0, args.state.score - 20].max
    end
  end
  
  args.state.player.x = VIRTUAL_WIDTH / 2
  args.state.player.y = VIRTUAL_HEIGHT / 2
  args.state.current_room = generate_room(args)
end