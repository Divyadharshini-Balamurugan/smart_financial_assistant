import requests
import json

OLLAMA_URL = "http://localhost:11434/api/generate"

# =========================================================
# MASTER CATEGORY DATA
# =========================================================

CATEGORY_DATA = {

    "expense": {

        "Food": {
            "id": "exp_food",
            "subcategories": {
                "Groceries": "food_groceries",
                "Restaurants": "food_restaurants",
                "Cafes": "food_cafes",
                "Snacks": "food_snacks",
                "Beverages": "food_beverages",
                "Takeaway / Delivery": "food_takeaway",
                "Street Food": "food_street_food"
            }
        },

        "Shopping": {
            "id": "exp_shopping",
            "subcategories": {
                "Clothing": "shop_clothing",
                "Footwear": "shop_footwear",
                "Accessories": "shop_accessories",
                "Electronics & Gadgets": "shop_electronics",
                "Home Decor": "shop_home_decor",
                "Furniture": "shop_furniture",
                "Online Shopping": "shop_online"
            }
        },

        "Travelling": {
            "id": "exp_travel",
            "subcategories": {
                "Fuel / Gas": "travel_fuel",
                "Public Transport": "travel_public",
                "Cab / Taxi": "travel_taxi",
                "Flight Tickets": "travel_flight",
                "Hotel / Accommodation": "travel_hotel",
                "Parking Fees": "travel_parking",
                "Toll Charges": "travel_toll"
            }
        },

        "Entertainment": {
            "id": "exp_entertainment",
            "subcategories": {
                "Movies / Shows": "ent_movies",
                "Subscriptions": "ent_subscriptions",
                "Events / Concerts": "ent_events",
                "Games / Apps": "ent_games",
                "Hobbies": "ent_hobbies",
                "Outdoor Activities": "ent_outdoor"
            }
        },

        "Medical": {
            "id": "exp_medical",
            "subcategories": {
                "Medicines": "med_medicines",
                "Doctor Consultation": "med_doctor",
                "Health Checkup": "med_checkup",
                "Hospitalization": "med_hospital",
                "Insurance Premiums": "med_insurance",
                "Dental Care": "med_dental",
                "Vision / Eye Care": "med_vision"
            }
        },

        "Personal Care": {
            "id": "exp_personal_care",
            "subcategories": {
                "Salon / Spa": "pc_salon",
                "Cosmetics / Beauty": "pc_cosmetics",
                "Fitness / Gym": "pc_fitness",
                "Skincare Products": "pc_skincare",
                "Personal Hygiene": "pc_hygiene",
                "Grooming Supplies": "pc_grooming"
            }
        },

        "Education": {
            "id": "exp_education",
            "subcategories": {
                "Tuition Fees": "edu_tuition",
                "Books & Supplies": "edu_books",
                "Online Courses": "edu_courses",
                "Coaching / Training": "edu_coaching",
                "Exam Fees": "edu_exam",
                "Stationery": "edu_stationery",
                "School / College Fees": "edu_school"
            }
        },

        "Bills & Utilities": {
            "id": "exp_bills",
            "subcategories": {
                "Electricity": "bill_electricity",
                "Water": "bill_water",
                "Internet / Wi-Fi": "bill_wifi",
                "Mobile / Phone": "bill_mobile",
                "Gas": "bill_gas",
                "TV / Cable": "bill_tv",
                "Maintenance Charges": "bill_maintenance"
            }
        },

        "Investment": {
            "id": "exp_investment",
            "subcategories": {
                "Stocks / Shares": "inv_stocks",
                "Mutual Funds": "inv_mutual",
                "Fixed Deposits": "inv_fd",
                "Cryptocurrency": "inv_crypto",
                "Real Estate": "inv_real_estate",
                "Bonds": "inv_bonds",
                "SIP Contributions": "inv_sip"
            }
        },

        "Rent": {
            "id": "exp_rent",
            "subcategories": {
                "House Rent": "rent_house",
                "Office / Workspace Rent": "rent_office",
                "Storage / Garage Rent": "rent_storage",
                "Equipment Lease": "rent_equipment"
            }
        },

        "Taxes": {
            "id": "exp_taxes",
            "subcategories": {
                "Income Tax": "tax_income",
                "Property Tax": "tax_property",
                "GST / Sales Tax": "tax_gst",
                "Vehicle Tax": "tax_vehicle",
                "Professional Tax": "tax_professional"
            }
        },

        "Gifts & Donations": {
            "id": "exp_gifts",
            "subcategories": {
                "Family Gifts": "gift_family",
                "Friend Gifts": "gift_friend",
                "Charity Donations": "gift_charity",
                "Religious Offerings": "gift_religious",
                "Wedding / Festival Gifts": "gift_wedding"
            }
        },

        "Other": {
            "id": "exp_other",
            "subcategories": {
                "Miscellaneous": "other_misc",
                "Service Charges": "other_service",
                "Unexpected Expenses": "other_unexpected",
                "Repairs & Maintenance": "other_repair",
                "Stationery": "other_stationery",
                "Lost Items": "other_lost",
                "Fines & Penalties": "other_fines"
            }
        }
    }
}

# =========================================================
# PAYMENT METHODS
# =========================================================

PAYMENT_METHODS = {
    "Cash": "pay_cash",
    "UPI": "pay_upi",
    "Credit Card": "pay_credit",
    "Debit Card": "pay_debit",
    "Net Banking": "pay_netbanking",
    "Wallet": "pay_wallet"
}

# =========================================================
# PROMPT
# =========================================================

PROMPT = """
You are a STRICT financial transaction parser.

Your task:
Convert the given sentence into VALID JSON ONLY.

IMPORTANT RULES:
- Return ONLY pure JSON
- No explanation
- No markdown
- No extra text
- No comments

--------------------------------------------------
VALID TYPES
--------------------------------------------------

Allowed values for "type":

1. expense
2. income
3. goal

You MUST choose ONLY one.

--------------------------------------------------
EXPENSE CATEGORIES
--------------------------------------------------

Allowed expense categories and subcategories:

Food:
- Groceries
- Restaurants
- Cafes
- Snacks
- Beverages
- Takeaway / Delivery
- Street Food

Shopping:
- Clothing
- Footwear
- Accessories
- Electronics & Gadgets
- Home Decor
- Furniture
- Online Shopping

Travelling:
- Fuel / Gas
- Public Transport
- Cab / Taxi
- Flight Tickets
- Hotel / Accommodation
- Parking Fees
- Toll Charges

Entertainment:
- Movies / Shows
- Subscriptions
- Events / Concerts
- Games / Apps
- Hobbies
- Outdoor Activities

Medical:
- Medicines
- Doctor Consultation
- Health Checkup
- Hospitalization
- Insurance Premiums
- Dental Care
- Vision / Eye Care

Personal Care:
- Salon / Spa
- Cosmetics / Beauty
- Fitness / Gym
- Skincare Products
- Personal Hygiene
- Grooming Supplies

Education:
- Tuition Fees
- Books & Supplies
- Online Courses
- Coaching / Training
- Exam Fees
- Stationery
- School / College Fees

Bills & Utilities:
- Electricity
- Water
- Internet / Wi-Fi
- Mobile / Phone
- Gas
- TV / Cable
- Maintenance Charges

Investment:
- Stocks / Shares
- Mutual Funds
- Fixed Deposits
- Cryptocurrency
- Real Estate
- Bonds
- SIP Contributions

Rent:
- House Rent
- Office / Workspace Rent
- Storage / Garage Rent
- Equipment Lease

Taxes:
- Income Tax
- Property Tax
- GST / Sales Tax
- Vehicle Tax
- Professional Tax

Gifts & Donations:
- Family Gifts
- Friend Gifts
- Charity Donations
- Religious Offerings
- Wedding / Festival Gifts

Other:
- Miscellaneous
- Service Charges
- Unexpected Expenses
- Repairs & Maintenance
- Stationery
- Lost Items
- Fines & Penalties

--------------------------------------------------
INCOME CATEGORIES
--------------------------------------------------

Salary and Stipend:
- Basic Salary
- Bonus
- Overtime
- Allowances
- Reimbursements

Business and Freelance:
- Project Payments
- Retainer Payments
- Consulting Fees
- Freelance Payments
- Invoice Payments

Allowance:
- Monthly Allowance
- Pocket Money
- Family Support

Scholarship and Grant:
- Merit Scholarship
- Research Grant
- Fellowship Stipend
- Travel Grant

Investment Income:
- Interest Earnings
- Dividends
- Capital Gains
- Mutual Fund Returns
- Crypto Gains
- Bond Interest

Rental Income:
- House Rent
- Commercial Property Rent
- Short Term Rental
- Parking Rent

Refunds and Cashback:
- Bank Refund
- Shopping Refund
- Payment Refund
- Cashback
- Reward Income

Gifts Received:
- Family Gift
- Friend Gift
- Event Gift

Other Income:
- Prize Money
- One Time Income
- Miscellaneous Income

--------------------------------------------------
GOAL CATEGORIES
--------------------------------------------------

Allowed goal categories:

- Emergency Fund
- Vacation / Trip
- New Phone
- New Laptop
- Education Savings
- Wedding Savings
- Car Purchase
- Bike Purchase
- Home Down Payment
- Home Renovation
- Medical Fund
- Investment Savings
- Festival Savings
- Birthday / Gifts Savings
- Travel Fund
- Retirement Fund

--------------------------------------------------
PAYMENT METHODS
--------------------------------------------------

Allowed payment methods ONLY:

- Cash
- UPI
- Credit Card
- Debit Card
- Net Banking
- Wallet

If payment method is not mentioned:
Use null

--------------------------------------------------
AMOUNT RULES
--------------------------------------------------

- amount must always be numeric
- remove currency words
- never return amount as string

Examples:
"200 rupees" -> 200
"₹500" -> 500

--------------------------------------------------
CURRENCY RULE
--------------------------------------------------

currency must ALWAYS be:

"INR"

--------------------------------------------------
STRICT MAPPING RULES
--------------------------------------------------

1. NEVER invent categories
2. NEVER invent subcategories
3. Choose ONLY from allowed values
4. category and subcategory MUST match correctly
5. If uncertain:
   - use category = "Other"
   - use subcategory = "Miscellaneous"

--------------------------------------------------
OUTPUT FORMAT
--------------------------------------------------

Expense:
{
  "type": "expense",
  "category": "Food",
  "subcategory": "Groceries",
  "amount": 100,
  "payment_method": "UPI",
  "currency": "INR"
}

Income:
{
  "type": "income",
  "category": "Salary and Stipend",
  "subcategory": "Basic Salary",
  "amount": 5000,
  "payment_method": "Bank Transfer",
  "currency": "INR"
}

Goal:
{
  "type": "goal",
  "category": "Travel Fund",
  "amount": 10000,
  "currency": "INR"
}

If payment method missing:
payment_method = others

Currency must ALWAYS be INR.

If uncertain:
category = Other
"""

# =========================================================
# JSON CLEANER
# =========================================================

def clean_json_output(raw_output):

    raw_output = raw_output.strip()

    start = raw_output.find("{")
    end = raw_output.rfind("}") + 1

    if start == -1 or end == 0:
        raise Exception("No valid JSON found")

    return raw_output[start:end]

# =========================================================
# MAIN PARSER
# =========================================================

def parse_expense(text):

    final_prompt = f"""
{PROMPT}

Sentence:
{text}

Return ONLY JSON.
"""

    response = requests.post(
        OLLAMA_URL,
        json={
            "model": "phi3",
            "prompt": final_prompt,
            "stream": False,
            "temperature": 0
        }
    )

    result = response.json()

    raw_output = result["response"]

    print("\nRAW OUTPUT:")
    print(raw_output)

    # =====================================================
    # CLEAN JSON
    # =====================================================

    clean_json = clean_json_output(raw_output)

    parsed = json.loads(clean_json)

    # =====================================================
    # EXTRACT VALUES
    # =====================================================

    transaction_type = parsed.get("type")

    category_name = parsed.get("category")
    subcategory_name = parsed.get("subcategory")

    amount = parsed.get("amount")

    payment_method_name = parsed.get("payment_method")

    currency = parsed.get("currency", "INR")

    # =====================================================
    # DEFAULT FALLBACKS
    # =====================================================

    if transaction_type not in ["expense", "income", "goal"]:
        transaction_type = "expense"

    # =====================================================
    # CATEGORY VALIDATION
    # =====================================================

    category_id = None
    subcategory_id = None

    if transaction_type == "expense":

        if category_name not in CATEGORY_DATA["expense"]:

            category_name = "Other"
            subcategory_name = "Miscellaneous"

        category_data = CATEGORY_DATA["expense"][category_name]

        category_id = category_data["id"]

        subcategories = category_data["subcategories"]

        if subcategory_name not in subcategories:
            subcategory_name = "Miscellaneous"

        subcategory_id = subcategories.get(subcategory_name)

    # =====================================================
    # PAYMENT VALIDATION
    # =====================================================

    payment_method_id = None

    if payment_method_name in PAYMENT_METHODS:
        payment_method_id = PAYMENT_METHODS[payment_method_name]
    else:
        payment_method_name = None

    # =====================================================
    # FINAL RESPONSE
    # =====================================================

    final_response = {

        "type": transaction_type,

        "category_id": category_id,
        "category_name": category_name,

        "subcategory_id": subcategory_id,
        "subcategory_name": subcategory_name,

        "amount": amount,

        "payment_mode_id": payment_method_id,
        "payment_mode_name": payment_method_name,

        "currency": currency
    }

    print("\nFINAL RESPONSE:")
    print(final_response)

    return final_response