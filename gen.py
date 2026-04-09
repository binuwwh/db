from faker import Faker
import psycopg2
import random
from datetime import date, timedelta

fake = Faker('ru_RU')

conn = psycopg2.connect(
    dbname="lab",
    user="postgres",
    password="Bina2004",  
    host="localhost",
    port="5432"
)

cur = conn.cursor()

for _ in range(30):
    cur.execute("""
        INSERT INTO client (passport_number, email, organization_name, address, fio)
        VALUES (%s, %s, %s, %s, %s)
    """, (
        fake.passport_number(),
        fake.email(),
        fake.company(),
        fake.city(),
        fake.name()
    ))
conn.commit() 
for _ in range(10):
    cur.execute("""
        INSERT INTO room (type, address, area, name)
        VALUES (%s, %s, %s, %s)
    """, (
        random.choice(['VIP', 'Hall', 'Open']),
        fake.address(),
        random.randint(50, 300),
        fake.word()
    ))
conn.commit() 
for _ in range(15):
    hire_date = fake.date_between(start_date='-5y', end_date='-1m')
    
    is_fired = random.random() < 0.2
    
    if is_fired:
        min_fire_date = hire_date + timedelta(days=30)
        if min_fire_date <= date.today():
            dismissal_date = fake.date_between(start_date=min_fire_date, end_date='today')
        else:
            dismissal_date = None
    else:
        dismissal_date = None
    
    cur.execute("""
        INSERT INTO employee (passport_number, iin, fio, birth_date, gender, phone, login, password, hire_date, dismissal_date)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        fake.passport_number(),
        fake.unique.bothify(text='##########'),
        fake.name(),
        fake.date_of_birth(minimum_age=20, maximum_age=50),
        random.choice(['M', 'F']),
        fake.phone_number(),
        fake.user_name(),
        '1234',
        hire_date,
        dismissal_date
    ))
conn.commit() 
positions = ["Manager", "Coordinator", "Technician", "Security", "Organizer"]

for p in positions:
    cur.execute("""
        INSERT INTO position (position_name)
        VALUES (%s)
    """, (p,))
conn.commit()  
cur.execute("SELECT id_employee, hire_date, dismissal_date FROM employee")
employees = cur.fetchall()

cur.execute("SELECT id_position FROM position")
position_ids = [x[0] for x in cur.fetchall()]

for employee_id, hire_date, dismissal_date in employees:
    position_id = random.choice(position_ids)
    start_date = hire_date  
    end_date = dismissal_date
    
    if end_date and end_date <= start_date:
        continue 
    
    cur.execute("""
        INSERT INTO history_position (id_employee, id_position, start_date, end_date)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """, (employee_id, position_id, start_date, end_date))
conn.commit() 
service_data = {
    "Photography": "Professional event photography with high-resolution images",
    "Video": "Full video recording and editing of the event",
    "DJ": "Experienced DJ with modern sound equipment",
    "Lighting": "Stage and ambient lighting setup",
    "Catering": "Full-service catering including food and drinks",
    "Decoration": "Venue decoration according to event theme",
    "Host": "Professional host to manage the event",
    "Security": "Security staff ensuring safety of guests",
    "Live Band": "Live music performance by professional band",
    "Dance Show": "Entertainment dance performance",
    "Magician": "Magic show for guests",
    "Karaoke": "Karaoke setup with sound system",
    "Bar Service": "Bartender service with drinks and cocktails",
    "Coffee Break": "Coffee and snacks for guests",
    "Candy Bar": "Sweet table with desserts",
    "Buffet": "Self-service food arrangement",
    "Floral Design": "Floral decoration and arrangements",
    "Photo Zone": "Decorated photo area for guests",
    "Balloon Decoration": "Decor with balloons",
    "Sound Equipment": "Professional sound system",
    "LED Screen": "Large LED display installation",
    "Projector": "Projector for presentations",
    "Transport Service": "Transportation for guests",
    "VIP Transfer": "Luxury transport service",
    "Event Planning": "Full event organization service",
    "Drone Shooting": "Aerial video shooting with drone",
    "Streaming Service": "Live streaming of the event"
}

used = set()
while len(used) < 20:
    service = random.choice(list(service_data.keys()))
    if service in used:
        continue
    used.add(service)
    cur.execute("""
        INSERT INTO service_price (service_name, description, cost)
        VALUES (%s, %s, %s)
    """, (
        service,
        service_data[service],
        random.randint(30000, 150000)
    ))
conn.commit() 
for _ in range(10):
    cur.execute("""
        INSERT INTO celebrity (stage_name, fee, contacts, performance_profile)
        VALUES (%s, %s, %s, %s)
    """, (
        fake.unique.first_name(),
        random.randint(50000, 300000),
        fake.phone_number(),
        random.choice(['DJ', 'Singer', 'Host'])
    ))
conn.commit() 
cur.execute("SELECT id_client FROM client")
client_ids = [x[0] for x in cur.fetchall()]

for client_id in client_ids:
    conclusion_date = fake.date_between(start_date='-1y', end_date='today')
    is_terminated = random.random() < 0.1
    if is_terminated:
        termination_date = fake.date_between(start_date=conclusion_date, end_date='today')
    else:
        termination_date = None
    
    cur.execute("""
        INSERT INTO contract (id_client, contract_number, contract_type, amount, conclusion_date, termination_date)
        VALUES (%s, %s, %s, %s, %s, %s)
    """, (
        client_id,
        f'C{client_id}',
        random.choice(['std', 'premium']),
        random.randint(100000, 1000000),
        conclusion_date,
        termination_date
    ))
conn.commit() 
cur.execute("SELECT id_contract FROM contract")
contract_ids = [x[0] for x in cur.fetchall()]

for i in range(30):
    cur.execute("""
        INSERT INTO event (id_contract, id_room, id_employee, name, description, event_date)
        VALUES (%s, %s, %s, %s, %s, %s)
    """, (
        random.choice(contract_ids),
        random.randint(1, 10),
        random.randint(1, 15),
        random.choice(["Wedding", "Conference", "Birthday", "Concert", "Meeting"]) + " #" + str(i),
        fake.text(max_nb_chars=50),
        fake.date_between(start_date='today', end_date='+1y')
    ))
conn.commit() 
cur.execute("SELECT id_event FROM event")
event_ids = [x[0] for x in cur.fetchall()]

cur.execute("SELECT id_service FROM service_price")
service_ids = [x[0] for x in cur.fetchall()]

for _ in range(80):
    cur.execute("""
        INSERT INTO selected_services (id_event, id_service, quantity)
        VALUES (%s, %s, %s)
        ON CONFLICT DO NOTHING
    """, (
        random.choice(event_ids),
        random.choice(service_ids),
        random.randint(1, 5)
    ))
conn.commit()

for contract_id in contract_ids:
    num_payments = random.randint(1, 3)
    for j in range(num_payments):
        cur.execute("""
            INSERT INTO payment_document (id_contract, document_number, type, payment_date)
            VALUES (%s, %s, %s, %s)
        """, (
            contract_id,
            f'P{contract_id}_{j+1}',
            random.choice(['payment', 'prepayment', 'final_payment']),
            fake.date_between(start_date='-6m', end_date='today')
        ))
conn.commit()

cur.execute("SELECT id_celebrity FROM celebrity")
celebrity_ids = [x[0] for x in cur.fetchall()]

for _ in range(40):
    cur.execute("""
        INSERT INTO performance (id_celebrity, id_contract)
        VALUES (%s, %s)
        ON CONFLICT DO NOTHING
    """, (
        random.choice(celebrity_ids),
        random.choice(contract_ids)
    ))
conn.commit()

cur.close()
conn.close()

print("generated")
