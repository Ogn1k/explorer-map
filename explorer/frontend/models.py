from django.db import models


class MapMark(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    name = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        super().save(*args, **kwargs)

        if is_new and (not self.name or not self.description):
            updates = {}
            if not self.name:
                updates["name"] = f"mark-name-{self.pk}"
            if not self.description:
                updates["description"] = f"mark-desc-{self.pk}"
            if updates:
                MapMark.objects.filter(pk=self.pk).update(**updates)
                for key, value in updates.items():
                    setattr(self, key, value)

    def __str__(self):
        return self.name or f"mark-{self.pk}"
