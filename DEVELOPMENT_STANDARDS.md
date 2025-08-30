# White Povar Development Standards & Guidelines

## 🎯 Core Development Principles

### 1. **Type Safety First**
- **Always implement robust parsing methods** with safe type conversion
- **Handle UUID-to-string conversion** explicitly using `.toString()`
- **Graceful null handling** with sensible defaults to prevent runtime errors
- **Never use direct type casting** without validation (avoid `as String`, use safe parsing)

### 2. **Performance-Oriented Database Design**
- **Use JOIN queries** to prevent N+1 query problems
- **Fetch related data in single database calls** whenever possible
- **Avoid thread executor patterns** - use direct async operations
- **Implement proper database connection pooling**

### 3. **Consistent Architecture Patterns**
- **Repository Pattern**: Decouple business logic from data access
- **Riverpod State Management**: Use consistently throughout Flutter app
- **Avoid mixed patterns**: No setState + Riverpod combinations
- **Service Layer Abstraction**: Clear separation between UI, business logic, and data

## 🛠️ Implementation Standards

### Frontend (Flutter)
```dart
// ✅ GOOD: Safe type conversion
factory Recipe.fromJson(Map<String, dynamic> json) {
  return Recipe(
    id: json['id'].toString(), // Handle UUID conversion
    title: json['title']?.toString() ?? '',
    amount: _parseDoubleSafely(json['amount']) ?? 0.0,
  );
}

// ❌ BAD: Direct casting
factory Recipe.fromJson(Map<String, dynamic> json) {
  return Recipe(
    id: json['id'] as String, // Can crash with UUIDs
    title: json['title'] as String, // Can crash with null
  );
}
```

### Backend (FastAPI)
```python
# ✅ GOOD: JOIN query
search_query = client.table('recipes').select('''
    *,
    recipe_ingredients(*)
''')

# ❌ BAD: N+1 queries
for recipe in recipes:
    ingredients = get_ingredients(recipe.id)  # Separate query each time
```

### Error Handling
```dart
// ✅ GOOD: Structured error handling
try {
  return await repository.searchRecipes(query);
} on RecipeRepositoryException catch (e) {
  state = state.copyWith(error: e.message);
} catch (e) {
  state = state.copyWith(error: 'An unexpected error occurred');
}

// ❌ BAD: Generic error handling
try {
  return await service.searchRecipes(query);
} catch (e) {
  throw Exception('Failed: $e'); // Not user-friendly
}
```

## 📋 Development Workflow

### Before Starting Any Task
1. **Information Gathering**
   - Use `codebase-retrieval` to understand existing patterns
   - Use `git-commit-retrieval` to see how similar changes were made
   - Identify potential breaking changes

2. **Planning Phase**
   - Create task breakdown for complex features
   - Consider impact on existing architecture
   - Plan for testing and validation

3. **Implementation Standards**
   - Follow established patterns in the codebase
   - Use package managers for dependencies (never edit package files manually)
   - Implement comprehensive logging with appropriate levels

### Error Handling Hierarchy
```
Frontend: ErrorHandler → Repository Exceptions → User-friendly messages
Backend: Custom Exceptions → Structured Responses → HTTP status codes
```

## 🔧 Technical Requirements

### Database Operations
- **Always use JOIN queries** for related data
- **Implement proper error handling** for database failures
- **Log database operations** with context but no sensitive data
- **Use async operations** without thread executors

### State Management
- **Riverpod only** for state management
- **No mixed setState/provider patterns**
- **Consistent provider structure** across features
- **Proper error state handling** in all providers

### API Integration
- **Repository pattern** for all external API calls
- **Standardized exception types** for different error categories
- **Consistent error response structure** with codes and types
- **Proper authentication handling** with token validation

## 🚀 Deployment & CI/CD

### Automatic Deployment
- **Changes auto-deploy** when pushed to main branch
- **Always test critical paths** after deployment
- **Monitor deployment logs** for errors
- **Rollback plan** for failed deployments

### Code Quality
- **Type safety validation** before commits
- **Error handling completeness** check
- **Performance impact assessment** for database changes
- **Breaking change analysis** for API modifications

## 🎨 User Experience Principles

### Error Messages
- **User-friendly language** instead of technical jargon
- **Actionable guidance** when possible
- **Consistent messaging** across the application
- **Proper error categorization** (network, auth, validation, server)

### Performance
- **Optimize database queries** to prevent timeouts
- **Implement proper loading states** for async operations
- **Cache frequently accessed data** when appropriate
- **Monitor and log performance metrics**

## 📝 Documentation Standards

### Code Documentation
- **Clear method signatures** with parameter descriptions
- **Error handling documentation** for each method
- **Performance considerations** for database operations
- **Breaking change notifications** in commit messages

### Commit Messages
```
Format: "Action: Brief description

- Specific change 1
- Specific change 2
- Impact/reasoning

Resolves: [issue description]"
```

## 🔍 Quality Assurance

### Before Deployment
- [ ] Type safety validation completed
- [ ] Error handling implemented and tested
- [ ] Database queries optimized (no N+1 problems)
- [ ] State management follows Riverpod patterns
- [ ] User-friendly error messages implemented
- [ ] Logging added with appropriate levels
- [ ] Breaking changes documented

### Post-Deployment
- [ ] Critical paths tested
- [ ] Error handling verified in production
- [ ] Performance metrics monitored
- [ ] User feedback collected and addressed

---

**Remember**: These standards exist to maintain code quality, prevent common issues, and ensure consistent user experience. Always prioritize type safety, performance, and user-friendly error handling in every implementation.
