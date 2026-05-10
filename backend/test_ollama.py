import requests
import json

prompt = """
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

--------------------------------------------------
USER SENTENCE
--------------------------------------------------
இன்று சலைக்கும் அம்பத்தையும் இருந்து கொண்டேன், 200 வெண்டு பாட்டிகளை கொள்ளவேண்டும் பை வண்டுடு வந்துட்டு பார்வாய் வாழ்க்கைகள் பார்வாய் வாழ்க்கைகள்

RETURN ONLY JSON.
"""

response = requests.post(
    "http://localhost:11434/api/generate",
    json={
        "model": "phi3",
        "prompt": prompt,
        "stream": False,
        "temperature": 0
    }
)

print(response.json()["response"])