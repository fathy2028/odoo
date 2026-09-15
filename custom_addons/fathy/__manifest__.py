{
    'name': "Fathy Shop",
    'version': '19.0.1.0.0',
    'category': 'Website/Website',
    'summary': "Fathy's Pick products and demo catalogue for the eCommerce shop",
    'description': """
Adds a "Fathy's Pick" flag on products. Flagged products automatically get the
"Fathy's Pick" ribbon in the online shop. Ships demo categories and products.
    """,
    'author': "Fathy",
    'depends': ['website_sale'],
    'data': [
        'data/product_ribbon_data.xml',
        'views/product_template_views.xml',
    ],
    'demo': [
        'demo/fathy_demo.xml',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
}
