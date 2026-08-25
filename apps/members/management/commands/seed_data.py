from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from apps.members.models import Member
from apps.agrovet.models import AgrovetItem, MemberPurchase
from decimal import Decimal

User = get_user_model()

class Command(BaseCommand):
    help = 'Seeds initial demo users, members, and agrovet stock'

    def handle(self, *args, **options):
        self.stdout.write("Seeding Kinyona Co-op demo data...")

        # 1. Create Staff Users
        admin_user, _ = User.objects.get_or_create(
            username='admin',
            defaults={
                'role': User.Roles.ADMIN,
                'is_staff': True,
                'is_superuser': True,
                'phone_number': '254700000000'
            }
        )
        admin_user.set_password('Admin123!')
        admin_user.save()

        collector, _ = User.objects.get_or_create(
            username='collector_john',
            defaults={
                'role': User.Roles.FIELD_COLLECTOR,
                'phone_number': '254711111111'
            }
        )
        collector.set_password('Collector123!')
        collector.save()

        # 2. Create Demo Members
        m1, _ = Member.objects.get_or_create(
            member_code='KIN-001',
            defaults={
                'full_name': 'Wanjiku Mwangi',
                'national_id': '12345678',
                'phone_number': '254708374149',  # Replace with sandbox test number if needed
                'preferred_payment_channel': Member.PaymentChannel.MPESA_B2C
            }
        )

        m2, _ = Member.objects.get_or_create(
            member_code='KIN-002',
            defaults={
                'full_name': 'Kamau Njoroge',
                'national_id': '87654321',
                'phone_number': '254712345678',
                'preferred_payment_channel': Member.PaymentChannel.MPESA_B2C
            }
        )

        # 3. Create Agrovet Inventory Items
        feed, _ = AgrovetItem.objects.get_or_create(
            name='High Yield Dairy Meal 50kg',
            defaults={'unit_price': Decimal('2800.00'), 'stock_quantity': 50}
        )

        salt, _ = AgrovetItem.objects.get_or_create(
            name='Mineral Salt Block 5kg',
            defaults={'unit_price': Decimal('850.00'), 'stock_quantity': 100}
        )

        # 4. Create Pending Store Credit Purchase for Member KIN-001
        MemberPurchase.objects.get_or_create(
            member=m1,
            description='High Yield Dairy Meal 50kg',
            defaults={
                'item': feed,
                'amount': Decimal('2800.00'),
                'status': MemberPurchase.Status.PENDING_DEDUCTION
            }
        )

        self.stdout.write(self.style.SUCCESS('Successfully seeded demo users, members, inventory, and pending credit purchases!'))