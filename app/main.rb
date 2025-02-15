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

BOONS = [
  {
    description: "+health",
    adjectives: ["good", "healthy"],
    gear: ["potion", "vial", "bottle", "flask", "chestplate", "helmet"],
    stat: :health,
    effect: ->(args) { args.state.player.health += 1 }
  },
  {
    description: "+bullet speed",
    adjectives: ["speedy", "lightning", "blast"],
    gear: ["gun", "bolt", "magic"],
    stat: :projectile_speed,
    effect: ->(args) do 
      args.state.player.projectile_speed += 0.1
    end
  },
  {
    description: "+attack",
    adjectives: ["strong", "powerful"],
    stat: :attack,
    gear: ["gloves", "gauntlets", "helmet", "chestplate", "boots"],
    effect: ->(args) { args.state.player.damage += 0.1 }
  },
  {
    description: "+speed",
    adjectives: ["fast", "swift"],
    gear: ["boots", "shoes", "clogs", "leggings"],
    stat: :speed,
    effect: ->(args) { args.state.player.speed += 0.1 }
  },
  {
    description: "+attack speed",
    adjectives: ["rapid", "quick-shot"],
    gear: ["stimpack", "gauntlets"],
    stat: :attack_speed,
    effect: ->(args) do 
      args.state.player.attack_speed -= 1
      args.state.player.attack_speed = 0 if args.state.player.attack_speed < 0
    end
  }
]

CURSES = [
  {
    description: "-health",
    adjectives: ["poisonous", "venomous"],
    stat: :health,
    effect: ->(args) { args.state.player.health -= 1 }
  },
  {
    description: "-attack",
    adjectives: ["weak", "fragile"],
    stat: :attack,
    effect: ->(args) do
      args.state.player.damage -= 0.5
      args.state.player.damage = 0.1 if args.state.player.damage < 0.1
    end
  },
  {
    description: "-speed",
    adjectives: ["slow", "slow-paced"],
    stat: :speed,
    effect: ->(args) do 
      args.state.player.speed -= 0.1
      args.state.player.speed = 0.1 if args.state.player.speed < 0.1
    end
  },
  {
    description: "+enemies",
    adjectives: ["many", "lots", "swarm"],
    effect: ->(args) { args.state.enemy_count += 1 }
  },
  {
    description: "+enemy speed",
    adjectives: ["fast", "swift"],
    stat: :speed,
    effect: ->(args) { args.state.enemy_speed += 0.1 }
  },
  {
    description: "-attack speed",
    adjectives: ["sluggish", "impeding"],
    stat: :attack_speed,
    effect: ->(args) do 
      args.state.player.attack_speed += 1
    end
  },
  {
    description: "-bullet speed",
    adjectives: ["muddy", "swamp", "hazy"],
    stat: :projectile_speed,
    effect: ->(args) do 
      args.state.player.projectile_speed -= 0.1
      args.state.player.projectile_speed = 0.1 if args.state.player.projectile_speed < 0.1
    end
  }
  
]

def tick(args)
  if args.state.tick_count.zero? 
    args.audio[:bg] = { input: "sounds/NanoBeats.ogg", looping: true }
    init_game(args) 

  end

  args.state.scaled_mouse_pos = {
    x: (args.inputs.mouse.x - OFFSET_X).idiv(ZOOM),
    y: (args.inputs.mouse.y - OFFSET_Y).idiv(ZOOM),
    w: 1, h: 1
  }

  handle_input(args)
  update_game(args)
  remove_destroyed(args)
  render_game(args)

end

def remove_destroyed(args)
  args.state.projectiles.reject!(&:destroyed)
  args.state.enemies.reject!(&:destroyed)
end

def init_game(args)
  args.state.player = {
    x: VIRTUAL_WIDTH / 2,
    y: VIRTUAL_HEIGHT / 2,
    w: 3,
    h: 3,
    speed: 1,
    damage: 1,
    health: 3,
    projectile_speed: 1.1,
    attack_speed: 30,
    attack_timer: 0,
    anchor_x: 0.5,
    anchor_y: 0.5,
    score: 0,
    r: 255, g: 255, b: 255,
    items: []
  }
  
  args.state.enemy_count = 3
  args.state.enemy_speed = 0.1
  args.state.enemy_damage = 1
  args.state.enemy_health = 1
  args.state.screen_shake_amt = 0
  args.state.projectiles = []
  args.state.enemies = []
  args.state.items = []
  args.state.game_state = :playing  # :playing or :choosing_item
  
  generate_room(args) if args.state.enemies.empty?
  args.state.help_alpha = 200
end

def handle_input(args)
  return handle_item_selection(args) if args.state.game_state == :choosing_item 
  return handle_game_over_selection(args) if args.state.game_state == :game_over
  
  move_x = 0
  move_y = 0
  
  if args.inputs.keyboard.key_held.left || args.inputs.keyboard.key_held.a
    move_x -= args.state.player.speed
  elsif args.inputs.keyboard.key_held.right || args.inputs.keyboard.key_held.d
    move_x += args.state.player.speed
  end
  
  if args.inputs.keyboard.key_held.up || args.inputs.keyboard.key_held.w
    move_y += args.state.player.speed
  elsif args.inputs.keyboard.key_held.down || args.inputs.keyboard.key_held.s
    move_y -= args.state.player.speed
  end
  
  args.state.player.x += move_x
  args.state.player.y += move_y
  
  if args.inputs.mouse.left
    attack(args, args.state.player, args.state.scaled_mouse_pos)  
  end
end

def update_game(args)
  args.state.player.x = args.state.player.x.clamp(0, VIRTUAL_WIDTH - args.state.player.w)
  args.state.player.y = args.state.player.y.clamp(0, VIRTUAL_HEIGHT - args.state.player.h)
  
  args.state.player.attack_timer -= 1 if args.state.player.attack_timer.positive?

  return if args.state.game_state == :game_over
  update_enemies(args)
  update_projectiles(args)
  check_room_cleared(args)
  check_dead(args)
end

def check_dead(args)
  if args.state.player.health <= 0
    args.state.game_state = :game_over
  end
end

def update_projectiles(args)
  args.state.projectiles.each do |projectile|
    projectile.sprite.x += projectile.vx
    projectile.sprite.y += projectile.vy

    if collision?(projectile.sprite, args.state.player)
      projectile.destroyed = true
      args.state.player.health -= projectile.damage
    end

    collision = args.geometry.find_intersect_rect projectile.sprite, args.state.enemies

    if collision
      collision.health -= projectile.damage
      projectile.destroyed = true 
      if collision.health <= 0 
        args.state.player.score += 10
        collision.destroyed = true
        args.state.screen_shake_amt = 7
        args.outputs.sounds << { input: "sounds/sfx_deathscream_robot2.wav" }
      else 
        args.outputs.sounds << { input: "sounds/sfx_sounds_impact4.wav" }
      end
    end
  end 
end

def render_game(args)
  args.outputs.background_color = [0, 0, 0]
  args.outputs[:scene].w = VIRTUAL_WIDTH
  args.outputs[:scene].h = VIRTUAL_HEIGHT
  args.outputs[:scene].background_color = [20, 20, 20]
  
  # Render player
  args.outputs[:scene].solids << args.state.player
  
  # Render enemies
  args.state.enemies.each do |enemy|
    args.outputs[:scene].solids << [
      enemy.x,
      enemy.y,
      enemy.w,
      enemy.h,
      255, 0, 0
    ]
  end

  args.state.projectiles.each do |projectile|
    args.outputs[:scene].solids << projectile.sprite
  end

  shake_x, shake_y = screen_shake(args)
  args.outputs.sprites << {
    x: WIDTH / 2 + (shake_x || 0),
    y: HEIGHT / 2 + (shake_y || 0),
    w: ZOOMED_WIDTH,
    h: ZOOMED_HEIGHT,
    anchor_x: 0.5,
    anchor_y: 0.5,
    path: :scene
  }
  
  # Render items if in choosing state
  if args.state.game_state == :choosing_item
    render_items(args)
  end

  if args.state.game_state == :game_over 
    render_game_over(args)
  end
  
  # Render stats
  args.outputs.labels << {
    x: 2,
    y: HEIGHT - 2,
    text: "DMG:#{args.state.player.damage.round(1)} SPD:#{args.state.player.speed.round(1)} ATK SPD: #{args.state.player.attack_speed.round(1)} BLT SPD #{args.state.player.projectile_speed.round(1)} HP:#{args.state.player.health.round(1)}",
    size_px: 24,
    r: 255,
    g: 255,
    b: 255
  }
  
  score_text = "SCORE: #{args.state.player.score}"
  args.outputs.labels << {
    x: (WIDTH / 2) - (args.gtk.calcstringbox(score_text, 12)[0] / 2),
    y: HEIGHT - 2,
    r: 255,
    g: 255,
    b: 255,
    text: score_text,
    size_enum: 12,
  }

  args.state.player.items.each_with_index do |item, i|
    args.outputs.labels << {
      x: 2,
      r: 255, g: 255, b: 255, a: 125,
      y: HEIGHT - (i * 25) - 50,
      text: item.name
    }
  end

  # Instructions on the right side
  instructions = [
    "HOW TO PLAY",
    "",
    "WASD - Move",
    "LEFT CLICK - Shoot",
    "",
    "Clear enemies each round",
    "Choose new items to power up",
    "But beware of their curses!",
    "",
    "Get the highest score!"
  ]

  instructions.each_with_index do |text, i|
    args.outputs.labels << {
      x: WIDTH - 10,
      y: HEIGHT - 50 - (i * 30),
      text: text,
      alignment_enum: 2, # Right-aligned
      size_enum: text == "HOW TO PLAY" ? 5 : 2,
      r: 255,
      g: 255,
      b: 255,
      a: args.state.help_alpha
    }
  end
end

def render_game_over(args)
  # Game Over text
  args.outputs.labels << {
    x: WIDTH / 2,
    y: HEIGHT - 200,
    text: "GAME OVER",
    size_enum: 20,
    alignment_enum: 1,
    r: 255,
    g: 0,
    b: 0,
  }

  # Score display
  args.outputs.labels << {
    x: WIDTH / 2,
    y: HEIGHT - 300,
    text: "FINAL SCORE: #{args.state.player.score}",
    size_enum: 15,
    alignment_enum: 1,
    r: 255,
    g: 255,
    b: 255,
  }

  # Play Again button
  button = {
    x: WIDTH / 2 - 100,
    y: HEIGHT - 400,
    w: 200,
    h: 50,
  }

  # Highlight on hover
  if args.inputs.mouse.point.inside_rect?(button)
    args.outputs.sprites << button.merge(r: 100, g: 100, b: 100)
  else
    args.outputs.sprites << button.merge(r: 50, g: 50, b: 50)
  end

  args.outputs.borders << button.merge(r: 255, g: 255, b: 255)
  
  args.outputs.labels << {
    x: button.x + 100,
    y: button.y + 35,
    text: "PLAY AGAIN",
    size_enum: 8,
    alignment_enum: 1,
    r: 255,
    g: 255,
    b: 255,
  }
end

def handle_game_over_selection(args)
  return unless args.inputs.mouse.click

  args.outputs.sounds << { input: "sounds/sfx_menu_move3.wav" }
  
  button = {
    x: WIDTH / 2 - 100,
    y: HEIGHT - 400,
    w: 200,
    h: 50,
  }

  if args.inputs.mouse.point.inside_rect?(button)
    init_game(args)
    args.state.game_state = :playing
  end
end

def generate_room(args)
  args.state.help_alpha = 0

  args.state.enemies = []
  args.state.items = []
  args.state.game_state = :playing

  args.state.player.x = VIRTUAL_WIDTH / 2
  args.state.player.y = VIRTUAL_HEIGHT / 2  
  
  args.state.enemy_count.times do
    angle = rand * Math::PI * 2
    
    spawn_radius = [VIRTUAL_WIDTH + 10, VIRTUAL_HEIGHT + 10].max / 2
    
    spawn_x = (VIRTUAL_WIDTH / 2) + Math.cos(angle) * spawn_radius
    spawn_y = (VIRTUAL_HEIGHT / 2) + Math.sin(angle) * spawn_radius
    
    args.state.enemies << {
      x: spawn_x,
      y: spawn_y,
      w: 3,
      h: 3,
      health: args.state.enemy_health,
      speed: args.state.enemy_speed,
      damage: args.state.enemy_damage,
    }
  end

  args.state.player.attack_timer = args.state.player.attack_speed
end

def update_enemies(args)
  args.state.enemies.each do |enemy|
    dx = args.state.player.x - enemy.x
    dy = args.state.player.y - enemy.y
    len = Math.sqrt(dx * dx + dy * dy)
    next unless len > 0
    
    enemy.x += (dx / len) * enemy.speed
    enemy.y += (dy / len) * enemy.speed
  end

  collision = args.geometry.find_intersect_rect args.state.player, args.state.enemies
  if collision
    args.outputs.sounds << { input: "sounds/sfx_sounds_impact3.wav" }
    args.state.player.health -= 1
    args.state.screen_shake_amt = 20
    
    dx = args.state.player.x - (collision.x + collision.w / 2)
    dy = args.state.player.y - (collision.y + collision.h / 2)
    len = Math.sqrt(dx * dx + dy * dy)
    
    # Apply knockback if we have a valid direction
    next unless len > 0 
    
    knockback = 8.0
    args.state.player.x += (dx / len) * knockback
    args.state.player.y += (dy / len) * knockback
  end
end

def screen_shake(args)
  return unless args.state.screen_shake_amt > 0
  
  intensity = args.state.screen_shake_amt
  args.state.screen_shake_amt = [args.state.screen_shake_amt - 1, 0].max
  
  [(rand(intensity * 2) - intensity) / 2,
   (rand(intensity * 2) - intensity) / 2]
end

def attack(args, from, to)
  return unless from.attack_timer.zero?
  
  from.attack_timer = from.attack_speed
  
  dx = to.x - from.x
  dy = to.y - from.y
  distance = Math.sqrt(dx * dx + dy * dy)
  vx = (dx / distance) * from.projectile_speed
  vy = (dy / distance) * from.projectile_speed

  args.state.screen_shake_amt = 5

  args.outputs.sounds << { input: "sounds/8bit_gunloop_explosion.wav" }
  args.state.projectiles << {
    sprite: {
      x: from.x + (vx * 2),
      y: from.y + (vy * 2),
      w: 1,
      h: 1,
      r: 255,
      g: 255,
      b: 255,
      anchor_x: 0.5,
      anchor_y: 0.5
    },
    damage: from.damage,
    vx: vx,
    vy: vy
  }
end

def check_room_cleared(args)
  if args.state.enemies.empty? && args.state.game_state == :playing
    start_choosing_items(args)
  end
end

def start_choosing_items(args)
  args.state.game_state = :choosing_item
  spawn_items(args)
end

def spawn_items(args)
  return if args.state.items.any?
    
  2.times do |i|
    buff = BOONS.sample
    curse = CURSES.reject { |c| c[:stat] == buff[:stat] }.sample
    name = "#{buff[:adjectives].sample} #{curse[:adjectives].sample} #{buff[:gear].sample}"
    
    args.state.items << {
      name: name,
      boon: buff,
      curse: curse,
      x: 320 + (i * 640),
      y: HEIGHT / 2,
      w: 60,
      h: 60
    }
  end
end

def render_items(args)
  args.outputs.labels << {
    x: WIDTH / 2,
    y: HEIGHT - 100,
    text: "CHOOSE ITEM",
    size_enum: 12,
    r: 255,
    g: 255,
    b: 255,
    anchor_x: 0.5
  }
  
  args.state.items.each do |item|
    container = {
      x: item.x + (item.w / 2),
      y: item.y - 130,
      w: 320,
      h: 120,
      anchor_x: 0.5,
    }

    hovered = args.inputs.mouse.point.inside_rect?(container)

    args.outputs.solids << [
      item.x,
      item.y,
      item.w,
      item.h,
      0, 255, 0
    ]

    args.outputs.borders << container
    args.outputs.sprites << container.merge(
      r: 255,
      b: 255,
      g: 255,
      a: hovered ? 125 : 0,
      path: :solid
    )

    
    args.outputs.labels << {
      x: item.x + (item.w / 2),
      y: item.y - 30,
      text: item.name,
      size_enum: 5,
      r: 255,
      g: 255,
      b: 255,
      anchor_x: 0.5
    }
    
    args.outputs.labels << {
      x: item.x + (item.w / 2),
      y: item.y - 60,
      text: item.boon.description,
      size_enum: 1,
      r: 0,
      g: 255,
      b: 0,
      anchor_x: 0.5
    }
    
    args.outputs.labels << {
      x: item.x + (item.w / 2),
      y: item.y - 90,
      text: item.curse.description,
      size_enum: 1,
      r: 255,
      g: 0,
      b: 0,
      anchor_x: 0.5
    }
  end
end

def handle_item_selection(args)
  return unless args.inputs.mouse.click
  
  args.state.items.each do |item|
    container = {
      x: item.x + (item.w / 2),
      y: item.y - 130,
      w: 320,
      h: 120,
      anchor_x: 0.5,
    }
    if args.geometry.intersect_rect?(args.inputs.mouse.point, container)
      args.outputs.sounds << { input: "sounds/sfx_menu_move3.wav" }
      apply_item(args, item)
      args.state.enemy_count += 1
      generate_room(args)
      break
    end
  end
end

def apply_item(args, item)
  args.state.player.items << item
  item.boon.effect.call(args)
  item.curse.effect.call(args)
end

def collision?(rect1, rect2)
  Geometry.intersect_rect?(rect1, rect2)
end