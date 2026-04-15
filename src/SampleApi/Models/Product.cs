namespace SampleApi.Models;

public record Product(int Id, string Name, string Category, decimal Price);

public class ProductStore
{
    private readonly List<Product> _products =
    [
        new(1, "Widget A", "Electronics", 29.99m),
        new(2, "Widget B", "Electronics", 49.99m),
        new(3, "Gadget X", "Accessories", 14.99m),
        new(4, "Gadget Y", "Accessories", 24.99m),
        new(5, "Service Pack", "Services", 99.99m),
    ];

    public IReadOnlyList<Product> GetAll() => _products.AsReadOnly();

    public Product? GetById(int id) => _products.FirstOrDefault(p => p.Id == id);

    public IReadOnlyList<Product> GetByCategory(string category) =>
        _products.Where(p => p.Category.Equals(category, StringComparison.OrdinalIgnoreCase)).ToList();
}
