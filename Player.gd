extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -350.0

@export var bullet_scene: PackedScene = preload("res://Scenes/Prefabs/bullet.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_dead: bool = false
var is_invincible: bool = false
var is_attacking: bool = false # เพิ่มตัวแปรเช็กสถานะโจมตี
var facing_direction: float = 1.0

func _ready() -> void:
	GameManager.player = self
	if not is_in_group("Player"):
		add_to_group("Player")

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_B:
			shoot()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1. แรงโน้มถ่วง
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. การกระโดด
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if jump_sound:
			jump_sound.play() # สั่งเล่นเสียงกระโดด

	# 3. การรับค่าเคลื่อนที่
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		facing_direction = direction
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 4. ประมวลผลฟิสิกส์
	move_and_slide()
	
	# 5. ตรวจจับการชนกับกับดัก/ศัตรู
	check_damage_collisions()
	
	# 6. อัปเดตแอนิเมชัน
	update_animation(direction)

func shoot() -> void:
	if bullet_scene == null:
		return
		
	# เล่นอนิเมชันโจมตี
	is_attacking = true
	if sprite.sprite_frames.has_animation("Attack_4"):
		sprite.play("Attack_4")
		
	var bullet = bullet_scene.instantiate()
	var spawn_offset = Vector2(facing_direction * 16, -32)
	bullet.global_position = global_position + spawn_offset
	
	if "direction" in bullet:
		bullet.direction = facing_direction
		
	get_parent().add_child(bullet)

	# หน่วงเวลาให้อกเล่นอนิเมชันฟัน/ยิงจนจบแล้วค่อยคืนค่า
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

func check_damage_collisions() -> void:
	if is_invincible or is_dead:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider:
			if collider.is_in_group("Traps"):
				take_damage(GameManager.max_hp)
				break
			elif collider.is_in_group("Enemy") or collider.is_in_group("Enemies") or collider is Enemy:
				take_damage(20)
				break

func update_animation(direction: float) -> void:
	if direction > 0:
		sprite.flip_h = false
	elif direction < 0:
		sprite.flip_h = true

	# ถ้ากำลังยิงอยู่ ให้เล่นอนิเมชัน Attack_4 ค้างไว้จนจบ
	if is_attacking:
		return

	if not is_on_floor():
		sprite.play("Jump")
	elif direction != 0:
		sprite.play("Run")
	else:
		sprite.play("Idle")

func take_damage(val: int = 10) -> void:
	if is_invincible or is_dead:
		return
		
	is_invincible = true
	GameManager.damage(val)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	await get_tree().create_timer(1.0).timeout
	is_invincible = false

func death_tween() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	if sprite.sprite_frames.has_animation("Dead"):
		sprite.play("Dead")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
