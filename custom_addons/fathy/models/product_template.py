from odoo import api, fields, models


class ProductTemplate(models.Model):
    _inherit = 'product.template'

    is_fathy_pick = fields.Boolean(
        string="Fathy's Pick",
        help="Highlight this product in the online shop with the \"Fathy's Pick\" ribbon.",
    )

    @api.model_create_multi
    def create(self, vals_list):
        products = super().create(vals_list)
        products._sync_fathy_ribbon()
        return products

    def write(self, vals):
        res = super().write(vals)
        if 'is_fathy_pick' in vals:
            self._sync_fathy_ribbon()
        return res

    def _sync_fathy_ribbon(self):
        """Put the Fathy's Pick ribbon on flagged products and remove it from unflagged ones."""
        ribbon = self.env.ref('fathy.ribbon_fathy_pick', raise_if_not_found=False)
        if not ribbon:
            return
        self.filtered('is_fathy_pick').website_ribbon_id = ribbon
        self.filtered(
            lambda p: not p.is_fathy_pick and p.website_ribbon_id == ribbon
        ).website_ribbon_id = False
