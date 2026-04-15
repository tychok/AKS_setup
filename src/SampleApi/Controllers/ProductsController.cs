using Microsoft.AspNetCore.Mvc;
using SampleApi.Models;

namespace SampleApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ProductStore _store;

    public ProductsController(ProductStore store)
    {
        _store = store;
    }

    [HttpGet]
    public IActionResult GetAll([FromQuery] string? category)
    {
        if (!string.IsNullOrWhiteSpace(category))
            return Ok(_store.GetByCategory(category));

        return Ok(_store.GetAll());
    }

    [HttpGet("{id:int}")]
    public IActionResult GetById(int id)
    {
        var product = _store.GetById(id);
        return product is null ? NotFound() : Ok(product);
    }
}
